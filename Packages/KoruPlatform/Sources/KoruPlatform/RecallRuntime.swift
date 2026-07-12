import AppKit
import Carbon
import KoruDomain
import SwiftUI

public enum RecallRuntimeHealth: Equatable, Sendable { case stopped, ready, permissionDenied, degraded }

private func currentInputSourceIsASCIICapable() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let rawValue = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(rawValue).takeUnretainedValue())
}

@MainActor
public final class RecallRuntime: @preconcurrency RuntimeIntegration {
    private let inspector: AccessibilityInspecting
    private let target: InsertionTargetAccessing
    private let index: InMemorySearchIndex
    private let repository: EncryptedSQLiteRepository
    private let permission: @Sendable () -> Bool
    private let pasteboard: NSPasteboard
    private let pointer: () -> CGPoint
    private let frontmostProcessIdentifier: @Sendable () -> pid_t?
    private let allowsRollingFallback: @Sendable () -> Bool
    private let clipboardContentResolver: (any ClipboardContentResolving)?
    private let syntheticReplaceOverride: ((String, SyntheticReplacementRequest) -> SyntheticReplacementOutcome)?
    private let panel = RecallPanelController()
    private var invocation: InvocationMode?
    private var trackedTarget: TargetSnapshot?
    private var results: [SearchResult] = []
    private var query = ""
    private var generation = 0
    private var rollingInput = ""
    private var automaticProcessIdentifier: pid_t?
    private var automaticGeneration: Int?
    private var automaticElementToken: String?
    private var automaticTargetIsSecure = false
    private var triggerCharacterCount = 0
    private var manualScope: SearchScope = .saved
    private var thumbnailCache: [ClipboardEventID: Data] = [:]
    private var thumbnailCacheBytes = 0
    private var contextTimer: Timer?
    public private(set) var health: RecallRuntimeHealth = .stopped

    public init(
        inspector: AccessibilityInspecting = SystemAccessibilityInspector(),
        target: InsertionTargetAccessing = SystemInsertionTarget(),
        index: InMemorySearchIndex,
        repository: EncryptedSQLiteRepository,
        permission: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
        pasteboard: NSPasteboard = .general,
        pointer: @escaping () -> CGPoint = { NSEvent.mouseLocation },
        frontmostProcessIdentifier: @escaping @Sendable () -> pid_t? = { NSWorkspace.shared.frontmostApplication?.processIdentifier },
        allowsRollingFallback: (@Sendable () -> Bool)? = nil,
        clipboardContentResolver: (any ClipboardContentResolving)? = nil,
        syntheticReplace: ((String, SyntheticReplacementRequest) -> SyntheticReplacementOutcome)? = nil
    ) {
        self.inspector = inspector; self.target = target; self.index = index; self.repository = repository
        self.permission = permission; self.pasteboard = pasteboard; self.pointer = pointer; self.frontmostProcessIdentifier = frontmostProcessIdentifier
        self.allowsRollingFallback = allowsRollingFallback ?? currentInputSourceIsASCIICapable
        self.clipboardContentResolver = clipboardContentResolver
        syntheticReplaceOverride = syntheticReplace
        panel.onSelect = { [weak self] id in self?.select(id: id) }
        panel.onCommand = { [weak self] message in self?.receive(message) ?? false }
    }

    // Typed tags can still open through the rolling event buffer when Accessibility cannot expose a
    // destination. Accessibility improves anchoring and direct replacement; it is no longer a gate.
    public func start() { health = .ready; if contextTimer == nil { contextTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.validateContext() } } } }
    public func stopAndPurge() { contextTimer?.invalidate(); contextTimer = nil; reset(); health = .stopped }

    /// Returns true only for panel commands that must not reach the destination.
    public func receive(_ message: TypedInputMessage) -> Bool {
        guard health == .ready || panel.isVisible else { return false }
        switch message {
        case let .character(value):
            if invocation == .manualRecall {
                guard panel.isVisible, !value.isEmpty else { return false }
                query.append(value); generation += 1; search(scope: manualScope, showEmpty: true); return true
            }
            receiveTypedCharacter(value); return false
        case .backspace:
            if invocation == .manualRecall, panel.isVisible {
                guard !query.isEmpty else { return true }
                query.removeLast(); generation += 1; search(scope: manualScope, showEmpty: true); return true
            }
            receiveTypedBackspace(); return false
        case let .navigation(delta):
            guard panel.isVisible else { reset(); return false }; panel.move(delta); return true
        case .confirm:
            guard panel.isVisible else { reset(); return false }
            guard panel.selectedID != nil else { return false }
            select(id: panel.selectedID!); return true
        case .copyConfirm:
            guard panel.isVisible else { reset(); return false }
            guard let selectedID = panel.selectedID else { return false }
            copySelected(id: selectedID); return true
        case .dismiss:
            let wasActive = panel.isVisible || invocation != nil
            reset(); return wasActive
        case .tabTransfer:
            if invocation == .manualRecall, panel.isVisible { return true }
            reset(); return false
        case .pointerDown:
            // Clicks inside the panel must reach its rows; clicks anywhere else dismiss the session.
            if panel.isVisible, panel.frame.contains(pointer()) { return false }
            reset(); return false
        case .reset:
            // Shortcut chords (including the hotkey that opened the panel) must not tear down a manual panel.
            if invocation == .manualRecall, panel.isVisible { return false }
            reset(); return false
        }
    }

    public func openManual(scope: SearchScope = .saved) {
        reset()
        invocation = .manualRecall
        trackedTarget = permission() ? target.currentSnapshot() : nil
        manualScope = scope
        query = ""; search(scope: scope, showEmpty: true)
    }

    private func receiveTypedCharacter(_ value: String) {
        guard !value.isEmpty, let pid = frontmostProcessIdentifier() else { reset(); return }
        clearAutomaticMatch(keepingRollingInput: true)
        if automaticProcessIdentifier != pid { rollingInput.removeAll(keepingCapacity: true) }
        automaticProcessIdentifier = pid
        rollingInput.append(value)
        if rollingInput.count > 512 { rollingInput = String(rollingInput.suffix(512)) }
        generation += 1
        scheduleAutomaticEvaluation(generation: generation, processIdentifier: pid)
    }

    private func receiveTypedBackspace() {
        guard let pid = frontmostProcessIdentifier() else { reset(); return }
        clearAutomaticMatch(keepingRollingInput: true)
        if automaticProcessIdentifier != pid { rollingInput.removeAll(keepingCapacity: true) }
        automaticProcessIdentifier = pid
        if !rollingInput.isEmpty { rollingInput.removeLast() }
        generation += 1
        scheduleAutomaticEvaluation(generation: generation, processIdentifier: pid)
    }

    private func scheduleAutomaticEvaluation(generation expectedGeneration: Int, processIdentifier pid: pid_t) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.generation == expectedGeneration,
                  self.frontmostProcessIdentifier() == pid,
                  self.invocation != .manualRecall else { return }
            self.evaluateAutomaticMatch(generation: expectedGeneration, processIdentifier: pid)
        }
    }

    private func evaluateAutomaticMatch(generation expectedGeneration: Int, processIdentifier pid: pid_t) {
        struct Candidate {
            let sourceText: String
            let caretUTF16: Int
            let usedAccessibilityValue: Bool
        }

        let rollingCandidate = Candidate(sourceText: rollingInput, caretUTF16: (rollingInput as NSString).length, usedAccessibilityValue: false)
        var candidates: [Candidate] = []
        var anchor: CGRect?
        var focusedElementToken: String?
        var focusedTargetIsSecure = false

        if case let .success(snapshot) = inspector.focusedTarget(), snapshot.processIdentifier == pid {
            anchor = snapshot.bounds
            focusedElementToken = snapshot.elementToken
            focusedTargetIsSecure = snapshot.isSecure
            if let value = snapshot.value, let range = snapshot.selectedRange,
               range.length == 0, range.location >= 0, range.location <= (value as NSString).length {
                let accessibilityCandidate = Candidate(sourceText: value, caretUTF16: range.location, usedAccessibilityValue: true)
                candidates.append(accessibilityCandidate)
            }
        }

        if allowsRollingFallback() {
            let accessibilityCandidateMatchesRolling = candidates.first?.sourceText == rollingCandidate.sourceText
                && candidates.first?.caretUTF16 == rollingCandidate.caretUTF16
            if !accessibilityCandidateMatchesRolling { candidates.append(rollingCandidate) }
        }

        Task { [weak self] in
            guard let self else { return }
            for candidate in candidates {
                if let clipboardRange = Self.exactSuffixRange(in: candidate.sourceText, caretUTF16: candidate.caretUTF16, trigger: KoruPolicy.reservedClipboardCommand) {
                    let found = await index.search("", scope: .clipboard, limit: 8, includeAllWhenEmpty: true)
                    guard self.generation == expectedGeneration, self.frontmostProcessIdentifier() == pid else { return }
                    await self.activateAutomaticMatch(results: found, invocation: .clipboardCommand, sourceText: candidate.sourceText, matchedRange: clipboardRange, caretUTF16: candidate.caretUTF16, usedAccessibilityValue: candidate.usedAccessibilityValue, anchor: anchor, focusedElementToken: focusedElementToken, focusedTargetIsSecure: focusedTargetIsSecure, processIdentifier: pid, generation: expectedGeneration)
                    return
                }

                let matches = await index.exactTriggerMatches(in: candidate.sourceText, caretUTF16: candidate.caretUTF16, limit: 8)
                guard self.generation == expectedGeneration, self.frontmostProcessIdentifier() == pid else { return }
                if let first = matches.first {
                    await self.activateAutomaticMatch(results: matches.map(\.result), invocation: .initialTypedMatch, sourceText: candidate.sourceText, matchedRange: first.replacementRange, caretUTF16: candidate.caretUTF16, usedAccessibilityValue: candidate.usedAccessibilityValue, anchor: anchor, focusedElementToken: focusedElementToken, focusedTargetIsSecure: focusedTargetIsSecure, processIdentifier: pid, generation: expectedGeneration)
                    return
                }
            }
            self.clearAutomaticMatch(keepingRollingInput: true)
        }
    }

    private func activateAutomaticMatch(results found: [SearchResult], invocation: InvocationMode, sourceText: String, matchedRange: NSRange, caretUTF16: Int, usedAccessibilityValue: Bool, anchor: CGRect?, focusedElementToken: String?, focusedTargetIsSecure: Bool, processIdentifier pid: pid_t, generation expectedGeneration: Int) async {
        guard matchedRange.location != NSNotFound, matchedRange.length > 0 else { return }
        let source = sourceText as NSString
        guard NSMaxRange(matchedRange) <= source.length else { return }
        let matchedText = source.substring(with: matchedRange)
        let rows = await recallRows(found)
        guard generation == expectedGeneration, frontmostProcessIdentifier() == pid else { return }

        var replacementTarget: TargetSnapshot?
        if let focusedElementToken,
           var current = target.currentSnapshot(), current.processIdentifier == pid,
           current.elementToken == focusedElementToken,
           current.replacementLength == 0, current.replacementLocation == caretUTF16 {
            let location = usedAccessibilityValue ? matchedRange.location : current.replacementLocation - matchedRange.length
            if location >= 0 {
                current.replacementLocation = location
                current.replacementLength = matchedRange.length
                replacementTarget = current
            }
        }

        self.invocation = invocation
        trackedTarget = replacementTarget
        results = found
        query = matchedText
        triggerCharacterCount = matchedText.count
        automaticProcessIdentifier = pid
        automaticGeneration = expectedGeneration
        automaticElementToken = focusedElementToken
        automaticTargetIsSecure = focusedTargetIsSecure
        let notice: String?
        if replacementTarget != nil {
            notice = nil
        } else if focusedElementToken == nil {
            notice = "Koru can show this match, but cannot verify the focused field. Return will copy it and leave the typed tag unchanged."
        } else if !CGPreflightPostEventAccess() {
            notice = "Koru can show this match, but macOS has not allowed keyboard replacement. Return will copy it and leave the typed tag unchanged."
        } else {
            notice = nil
        }
        panel.present(rows: rows, source: invocation == .clipboardCommand ? "Clipboard" : "Saved", query: matchedText, caret: anchor, notice: notice, keyboardFocus: false)
    }

    private func search(scope: SearchScope, showEmpty: Bool) {
        let activeQuery = query; let currentGeneration = generation
        Task { [weak self] in
            guard let self else { return }
            let reservedClipboardRecall = scope == .clipboard && activeQuery == KoruPolicy.reservedClipboardCommand
            let searchQuery = reservedClipboardRecall ? "" : activeQuery
            let found = await index.search(searchQuery, scope: scope, limit: 8, includeAllWhenEmpty: showEmpty || reservedClipboardRecall)
            guard self.generation == currentGeneration, self.query == activeQuery else { return }
            let rows = await self.recallRows(found)
            guard self.generation == currentGeneration, self.query == activeQuery else { return }
            self.results = found
            guard showEmpty || !found.isEmpty || activeQuery == KoruPolicy.reservedClipboardCommand else { self.panel.dismiss(); return }
            let anchor = (try? self.focusSnapshot())?.bounds
            let notice = self.permission() ? nil : "Accessibility is off, so the panel cannot follow your cursor and Return copies to the clipboard. Enable Koru in System Settings › Privacy & Security › Accessibility."
            self.panel.present(rows: rows, source: scope == .saved ? "Saved" : "Clipboard", query: activeQuery, caret: anchor, notice: notice, keyboardFocus: self.invocation == .manualRecall && self.trackedTarget == nil)
        }
    }

    private func recallRows(_ found: [SearchResult]) async -> [RecallResult] {
        let maximumSessionBytes = 2 * 1024 * 1024
        let maximumNewImageRows = 4
        var hydratedImageRows = 0
        var rows: [RecallResult] = []
        rows.reserveCapacity(found.count)

        for result in found {
            var thumbnail: Data?
            if result.contentType == .image, case let .clipboard(eventID) = result.source {
                thumbnail = thumbnailCache[eventID]
                let remaining = maximumSessionBytes - thumbnailCacheBytes
                if thumbnail == nil, hydratedImageRows < maximumNewImageRows, remaining >= 64 * 1024,
                   let resolver = clipboardContentResolver,
                   let loaded = try? await resolver.thumbnail(eventID: eventID, maximumBytes: min(512 * 1024, remaining)),
                   !loaded.isEmpty, loaded.count <= remaining {
                    thumbnailCache[eventID] = loaded
                    thumbnailCacheBytes += loaded.count
                    thumbnail = loaded
                    hydratedImageRows += 1
                }
            }
            rows.append(.init(id: Self.id(result.source), title: result.title, preview: result.preview ?? result.reason, contentType: result.contentType, thumbnailData: thumbnail))
        }
        return rows
    }

    private func select(id: String) {
        guard let result = results.first(where: { Self.id($0.source) == id }), let invocation else { reset(); return }
        let original = trackedTarget
        let selectedGeneration = generation
        let selectedAutomaticGeneration = automaticGeneration
        let selectedElementToken = automaticElementToken
        let selectedTargetIsSecure = automaticTargetIsSecure
        let selectedPID = automaticProcessIdentifier
        let selectedTriggerCharacters = triggerCharacterCount
        let selectedQuery = query
        Task { [weak self] in
            guard let self else { return }
            if result.contentType == .image, case let .clipboard(eventID) = result.source {
                await self.selectClipboardImage(
                    eventID: eventID,
                    invocation: invocation,
                    originalTarget: original,
                    selectedGeneration: selectedGeneration,
                    automaticGeneration: selectedAutomaticGeneration,
                    elementToken: selectedElementToken,
                    processIdentifier: selectedPID,
                    triggerCharacterCount: selectedTriggerCharacters
                )
                return
            }
            let text: String?
            let itemID: SavedItemID?
            switch result.source {
            case let .saved(id): text = (try? await repository.item(id: id)?.plainContent) ?? result.preview; itemID = id
            case let .clipboard(id): text = (try? await repository.clipboardEvents().first(where: { $0.event.id == id })?.searchableText) ?? result.preview; itemID = nil
            }
            guard let text else { self.reset(); return }
            guard self.invocation == invocation, self.generation == selectedGeneration else { self.reset(); return }
            if invocation == .manualRecall, original == nil {
                _ = KoruPasteboardOrigin.write(text, to: self.pasteboard)
                self.reset()
                return
            }

            if invocation == .manualRecall, var insertionTarget = original {
                if let current = target.currentSnapshot() { insertionTarget = current }
                let transaction = InsertionTransaction(invocation: invocation, target: insertionTarget, selectedItemID: itemID, requestedTier: .directAccessibility, explicitlyConfirmed: true)
                let capability: CompatibilityCapability = AXIsProcessTrusted() ? .full : (CGPreflightPostEventAccess() ? .paste : .copyOnly)
                _ = InsertionCoordinator(target: target, pasteboard: pasteboard).insert(text, transaction: transaction, capability: capability)
                if let itemID { await index.recordSelection(query: selectedQuery, itemID: itemID, appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
                self.reset()
                return
            }

            // A verified whole-value AX splice is the safest first choice for plain WebKit inputs:
            // embedded hosts may have no Edit/Paste responder route at all. Rich or unreadable fields
            // fall back to guarded Backspace + direct Unicode keyboard input, which does not require
            // a Paste command and preserves surrounding editor structure.
            var insertedAutomatically = false
            var automaticContextIsSafe = true
            if let original, !selectedTargetIsSecure {
                let transaction = InsertionTransaction(invocation: invocation, target: original, selectedItemID: itemID, requestedTier: .directAccessibility, explicitlyConfirmed: true)
                let outcome = InsertionCoordinator(target: target, pasteboard: pasteboard).insertDirectAccessibility(text, transaction: transaction)
                if case .inserted = outcome { insertedAutomatically = true }
                if case .cancelledTargetChanged = outcome { automaticContextIsSafe = false }
            }
            if !insertedAutomatically, automaticContextIsSafe,
               let pid = selectedPID, let matchGeneration = selectedAutomaticGeneration,
               selectedElementToken != nil,
               self.generation == matchGeneration, self.frontmostProcessIdentifier() == pid {
                let request = SyntheticReplacementRequest(expectedProcessIdentifier: pid, expectedGeneration: matchGeneration, expectedElementToken: selectedElementToken, deletionCharacterCount: selectedTriggerCharacters, explicitlyConfirmed: true)
                let outcome = self.performSyntheticReplacement(text, request: request)
                insertedAutomatically = outcome == .inserted
                if outcome == .cancelledContextChanged { automaticContextIsSafe = false }
            }

            if !insertedAutomatically {
                // Selection was explicit, so copying is useful recovery; no destructive input is
                // posted after a context change or an unverifiable destination.
                _ = KoruPasteboardOrigin.write(text, to: self.pasteboard)
            }
            if let itemID { await index.recordSelection(query: selectedQuery, itemID: itemID, appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
            self.reset()
        }
    }

    /// Control-Return copies the highlighted result to the clipboard and closes the panel without
    /// touching the destination field: the typed tag stays in place and nothing is inserted.
    private func copySelected(id: String) {
        guard let result = results.first(where: { Self.id($0.source) == id }), invocation != nil else { reset(); return }
        let selectedGeneration = generation
        let selectedQuery = query
        Task { [weak self] in
            guard let self else { return }
            if result.contentType == .image, case let .clipboard(eventID) = result.source {
                if let resolver = self.clipboardContentResolver,
                   let content = try? await resolver.image(eventID: eventID),
                   self.generation == selectedGeneration {
                    _ = KoruPasteboardOrigin.writeImage(content, to: self.pasteboard)
                }
                self.reset()
                return
            }
            let text: String?
            let itemID: SavedItemID?
            switch result.source {
            case let .saved(id): text = (try? await repository.item(id: id)?.plainContent) ?? result.preview; itemID = id
            case let .clipboard(id): text = (try? await repository.clipboardEvents().first(where: { $0.event.id == id })?.searchableText) ?? result.preview; itemID = nil
            }
            guard let text, self.generation == selectedGeneration else { self.reset(); return }
            _ = KoruPasteboardOrigin.write(text, to: self.pasteboard)
            if let itemID { await index.recordSelection(query: selectedQuery, itemID: itemID, appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
            self.reset()
        }
    }

    private func selectClipboardImage(
        eventID: ClipboardEventID,
        invocation: InvocationMode,
        originalTarget: TargetSnapshot?,
        selectedGeneration: Int,
        automaticGeneration: Int?,
        elementToken: String?,
        processIdentifier: pid_t?,
        triggerCharacterCount: Int
    ) async {
        guard let resolver = clipboardContentResolver,
              let content = try? await resolver.image(eventID: eventID),
              invocation == self.invocation, selectedGeneration == generation,
              KoruPasteboardOrigin.writeImage(content, to: pasteboard) else { reset(); return }

        var insertedAutomatically = false
        if invocation != .manualRecall,
           let pid = processIdentifier, let matchGeneration = automaticGeneration, elementToken != nil,
           generation == matchGeneration, frontmostProcessIdentifier() == pid {
            let request = SyntheticReplacementRequest(expectedProcessIdentifier: pid, expectedGeneration: matchGeneration, expectedElementToken: elementToken, deletionCharacterCount: triggerCharacterCount, explicitlyConfirmed: true)
            insertedAutomatically = performSyntheticPreparedPaste(request: request) == .inserted
        }

        if !insertedAutomatically, let originalTarget {
            let transaction = InsertionTransaction(invocation: invocation, target: originalTarget, requestedTier: .pasteboardAndPaste, explicitlyConfirmed: true)
            _ = InsertionCoordinator(target: target, pasteboard: pasteboard).pastePreparedContent(transaction: transaction)
        }
        reset()
    }

    private func focusSnapshot() throws -> AXTargetSnapshot { switch inspector.focusedTarget() { case let .success(value): value; case let .failure(error): throw error } }
    private func performSyntheticReplacement(_ text: String, request: SyntheticReplacementRequest) -> SyntheticReplacementOutcome {
        if let syntheticReplaceOverride { return syntheticReplaceOverride(text, request) }
        return SyntheticReplacementCoordinator(pasteboard: pasteboard, context: liveSyntheticContext(request: request)).replace(text, request: request)
    }
    private func performSyntheticPreparedPaste(request: SyntheticReplacementRequest) -> SyntheticReplacementOutcome {
        if let syntheticReplaceOverride { return syntheticReplaceOverride("", request) }
        return SyntheticReplacementCoordinator(pasteboard: pasteboard, context: liveSyntheticContext(request: request)).replacePreparedPasteboard(request: request)
    }
    private func liveSyntheticContext(request: SyntheticReplacementRequest) -> SyntheticReplacementCoordinator.Context {
        { [weak self] in
            guard Thread.isMainThread else { return (nil, .min, nil) }
            return MainActor.assumeIsolated {
                guard let self else { return (nil, .min, nil) }
                let focusedToken: String?
                if case let .success(snapshot) = self.inspector.focusedTarget(), snapshot.processIdentifier == request.expectedProcessIdentifier {
                    focusedToken = snapshot.elementToken
                } else {
                    focusedToken = nil
                }
                return (self.frontmostProcessIdentifier(), self.generation, focusedToken)
            }
        }
    }
    private static func id(_ source: SearchResult.Source) -> String { switch source { case let .saved(id): "saved:\(id)"; case let .clipboard(id): "clipboard:\(id)" } }
    private static func exactSuffixRange(in value: String, caretUTF16: Int, trigger: String) -> NSRange? {
        guard trigger.count >= KoruPolicy.minimumTriggerLength else { return nil }
        let source = value as NSString
        guard caretUTF16 >= 0, caretUTF16 <= source.length else { return nil }
        let range = source.range(of: trigger, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .backwards, .anchored], range: NSRange(location: 0, length: caretUTF16))
        guard range.location != NSNotFound, NSMaxRange(range) == caretUTF16 else { return nil }
        if range.location > 0, let preceding = source.substring(to: range.location).last, preceding.isLetter || preceding.isNumber { return nil }
        return range
    }
    private func validateContext() {
        guard let invocation else { return }
        if invocation == .manualRecall, trackedTarget == nil { return }
        if let trackedTarget {
            guard let current = target.currentSnapshot(),
                  current.processIdentifier == trackedTarget.processIdentifier,
                  current.elementToken == trackedTarget.elementToken,
                  current.expectedValueDigest == trackedTarget.expectedValueDigest else { reset(); return }
            if invocation == .manualRecall {
                guard current.replacementLocation == trackedTarget.replacementLocation,
                      current.replacementLength == trackedTarget.replacementLength else { reset(); return }
            } else {
                guard current.replacementLocation == trackedTarget.replacementLocation + trackedTarget.replacementLength,
                      current.replacementLength == 0 else { reset(); return }
            }
        } else if invocation != .manualRecall {
            guard frontmostProcessIdentifier() == automaticProcessIdentifier else { reset(); return }
        }
    }
    private func clearAutomaticMatch(keepingRollingInput: Bool) {
        guard invocation != .manualRecall else { return }
        invocation = nil; trackedTarget = nil; results = []; query.removeAll(keepingCapacity: false)
        triggerCharacterCount = 0; automaticGeneration = nil; automaticElementToken = nil; automaticTargetIsSecure = false; panel.dismiss()
        if !keepingRollingInput { rollingInput.removeAll(keepingCapacity: false); automaticProcessIdentifier = nil }
    }
    private func reset() { generation += 1; invocation = nil; trackedTarget = nil; results = []; query.removeAll(keepingCapacity: false); rollingInput.removeAll(keepingCapacity: false); automaticProcessIdentifier = nil; automaticGeneration = nil; automaticElementToken = nil; automaticTargetIsSecure = false; triggerCharacterCount = 0; thumbnailCache.removeAll(keepingCapacity: false); thumbnailCacheBytes = 0; panel.dismiss() }

    // Internal observation hooks are intentionally unavailable to app clients and exist for deterministic tests.
    var queryForTesting: String { query }
    var resultTitlesForTesting: [String] { results.map(\.title) }
    var panelIsVisibleForTesting: Bool { panel.isVisible }
    var panelFrameForTesting: CGRect { panel.frame }
    var panelSelectedIDForTesting: String? { panel.selectedID }
    var panelAcceptsKeyboardForTesting: Bool { panel.acceptsKeyboard }
    var panelNoticeForTesting: String? { panel.currentNotice }
    var panelRowsForTesting: [RecallResult] { panel.rows }
}

@MainActor private final class RecallPanelController {
    private let panel = KoruPanel(contentRect: .init(x: 0, y: 0, width: RecallPanelLayout.width, height: RecallPanelLayout.minimumHeight))
    private let layout = RecallPanelLayout()
    private var navigator = ResultNavigator()
    var onSelect: ((String) -> Void)?
    var onCommand: ((TypedInputMessage) -> Bool)?
    private var source = "Saved"; private var query = ""; private var notice: String?
    var isVisible: Bool { panel.isVisible }
    var selectedID: String? { navigator.selectedID }
    var frame: CGRect { panel.frame }
    var acceptsKeyboard: Bool { panel.allowsKeyboardFocus }
    var currentNotice: String? { notice }
    var rows: [RecallResult] { navigator.results }
    init() { panel.contentView = FirstMouseHostingView(rootView: AnyView(EmptyView())); panel.onPanelCommand = { [weak self] message in self?.onCommand?(message) ?? false } }
    func present(rows: [RecallResult], source: String, query: String, caret: CGRect?, notice: String? = nil, keyboardFocus: Bool = false) { self.source = source; self.query = query; self.notice = notice; navigator.update(rows); let height = layout.panelHeight(rows: rows, showsClipboardHeader: source == "Clipboard", notice: notice); panel.setContentSize(.init(width: RecallPanelLayout.width, height: height)); render(source: source, query: query); let caretAppKit = CaretPanelPlacer.appKitRect(fromAX: caret, primaryScreenHeight: NSScreen.screens.first?.frame.maxY ?? 0); let screen = NSScreen.screens.first(where: { screen in caretAppKit.map(screen.frame.intersects) ?? false }) ?? NSScreen.main; guard let screen else { return }; let placement = CaretPanelPlacer().place(panelSize: panel.frame.size, caret: caretAppKit, visibleFrame: screen.visibleFrame); panel.setFrameOrigin(placement.origin); panel.allowsKeyboardFocus = keyboardFocus; if keyboardFocus { panel.makeKeyAndOrderFront(nil) } else { panel.orderFrontRegardless() } }
    func move(_ delta: Int) { navigator.move(delta); render(source: source, query: query) }
    func dismiss() { navigator.dismiss(); panel.orderOut(nil); panel.allowsKeyboardFocus = false }
    private func render(source: String, query: String) { let selected = navigator.selectedID; let action = onSelect; panel.contentView = FirstMouseHostingView(rootView: AnyView(RecallPanelContentView(source: source, query: query, rows: navigator.results, selectedID: selected, notice: notice, select: { action?($0) }))) }
}
