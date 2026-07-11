import AppKit
import KoruDomain
import SwiftUI

public enum RecallRuntimeHealth: Equatable, Sendable { case stopped, ready, permissionDenied, degraded }

@MainActor
public final class RecallRuntime: @preconcurrency RuntimeIntegration {
    private let inspector: AccessibilityInspecting
    private let target: InsertionTargetAccessing
    private let index: InMemorySearchIndex
    private let repository: EncryptedSQLiteRepository
    private let exclusions: @Sendable () -> Set<String>
    private let permission: @Sendable () -> Bool
    private let panel = RecallPanelController()
    private var session = FreshInputSession()
    private var invocation: InvocationMode?
    private var trackedTarget: TargetSnapshot?
    private var results: [SearchResult] = []
    private var query = ""
    private var generation = 0
    private var isAwaitingTypedCommit = false
    private var contextTimer: Timer?
    public private(set) var health: RecallRuntimeHealth = .stopped

    public init(inspector: AccessibilityInspecting = SystemAccessibilityInspector(), target: InsertionTargetAccessing = SystemInsertionTarget(), index: InMemorySearchIndex, repository: EncryptedSQLiteRepository, exclusions: @escaping @Sendable () -> Set<String> = { [] }, permission: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() }) {
        self.inspector = inspector; self.target = target; self.index = index; self.repository = repository; self.exclusions = exclusions; self.permission = permission
        panel.onSelect = { [weak self] id in self?.select(id: id) }
    }

    public func start() { health = permission() ? .ready : .permissionDenied; if !permission() { reset() }; if contextTimer == nil { contextTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.validateContext() } } } }
    public func stopAndPurge() { contextTimer?.invalidate(); contextTimer = nil; reset(); health = .stopped }

    /// Returns true only for panel commands that must not reach the destination.
    public func receive(_ message: TypedInputMessage) -> Bool {
        guard health == .ready else { return false }
        switch message {
        case let .character(value):
            guard invocation != .manualRecall else { return false }
            beginOrContinueTyped(value); return false
        case let .navigation(delta):
            guard panel.isVisible else { reset(); return false }; panel.move(delta); return true
        case .confirm:
            guard panel.isVisible, panel.selectedID != nil else { return false }; select(id: panel.selectedID!); return true
        case .dismiss:
            let wasActive = panel.isVisible || invocation != nil; guard wasActive else { return false }; reset(); return wasActive
        case .tabTransfer:
            guard panel.isVisible else { return false }; session.handle(.tabTransfer); return true
        case .reset: reset(); return false
        }
    }

    public func openManual(scope: SearchScope = .saved) {
        if health != .ready || !prepareTarget(invocation: .manualRecall, requireEmpty: false) {
            reset()
            invocation = .manualRecall
            trackedTarget = nil
        }
        query = ""; search(scope: scope, showEmpty: true)
    }

    private func beginOrContinueTyped(_ value: String) {
        guard value.count == 1, let character = value.first else { reset(); return }
        if invocation == nil {
            guard prepareTarget(invocation: .initialTypedMatch, requireEmpty: true) else { return }
        }
        guard invocation == .initialTypedMatch || invocation == .clipboardCommand else { return }
        query.append(character)
        session.handle(.committedCharacter(character, hasQualifyingMatch: query == KoruPolicy.reservedClipboardCommand))
        generation += 1; let currentGeneration = generation; let expected = query
        isAwaitingTypedCommit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, self.generation == currentGeneration, let snapshot = self.target.currentSnapshot(), let tracked = self.trackedTarget,
                  snapshot.processIdentifier == tracked.processIdentifier, snapshot.elementToken == tracked.elementToken else { self?.reset(); return }
            guard snapshot.replacementLocation == expected.utf16.count, snapshot.replacementLength == 0 else { self.reset(); return }
            self.isAwaitingTypedCommit = false
            let clipboard = expected == KoruPolicy.reservedClipboardCommand
            if clipboard { self.invocation = .clipboardCommand }
            self.search(scope: clipboard ? .clipboard : .saved, showEmpty: false)
        }
    }

    private func prepareTarget(invocation: InvocationMode, requireEmpty: Bool) -> Bool {
        guard permission(), case let .success(snapshot) = inspector.focusedTarget() else { health = .permissionDenied; reset(); return false }
        let bundleID = NSRunningApplication(processIdentifier: snapshot.processIdentifier)?.bundleIdentifier
        let excluded = bundleID.map { exclusions().contains($0) } ?? true
        let location = snapshot.selectedRange?.location; let length = snapshot.selectedRange?.length
        session.handle(.focus(value: snapshot.value, selectionLocation: location, selectionLength: length, editable: snapshot.isEditable, secure: snapshot.isSecure, excluded: excluded))
        if requireEmpty { guard session.state == .eligibleEmptyStart else { reset(); return false } }
        guard snapshot.isEditable, !snapshot.isSecure, !excluded, let target = target.currentSnapshot() else { reset(); return false }
        self.invocation = invocation; trackedTarget = target; query = ""; return true
    }

    private func search(scope: SearchScope, showEmpty: Bool) {
        let activeQuery = query; let currentGeneration = generation
        Task { [weak self] in
            guard let self else { return }
            let reservedClipboardRecall = scope == .clipboard && activeQuery == KoruPolicy.reservedClipboardCommand
            let searchQuery = reservedClipboardRecall ? "" : activeQuery
            let found = await index.search(searchQuery, scope: scope, limit: 8, includeAllWhenEmpty: showEmpty || reservedClipboardRecall)
            guard self.generation == currentGeneration, self.query == activeQuery else { return }
            self.results = found
            guard showEmpty || !found.isEmpty || activeQuery == KoruPolicy.reservedClipboardCommand else { self.panel.dismiss(); return }
            let rows = found.map { RecallResult(id: Self.id($0.source), title: $0.title, preview: $0.preview ?? $0.reason) }
            let anchor = (try? self.focusSnapshot())?.bounds
            self.panel.present(rows: rows, source: scope == .saved ? "Saved" : "Clipboard", query: activeQuery, caret: anchor)
        }
    }

    private func select(id: String) {
        guard let result = results.first(where: { Self.id($0.source) == id }), let invocation else { reset(); return }
        let original = trackedTarget
        Task { [weak self] in
            guard let self else { return }
            let text: String?
            let itemID: SavedItemID?
            switch result.source {
            case let .saved(id): text = try? await repository.item(id: id)?.plainContent; itemID = id
            case let .clipboard(id): text = try? await repository.clipboardEvents().first(where: { $0.event.id == id })?.searchableText; itemID = nil
            }
            guard let text else { self.reset(); return }
            guard let original else {
                NSPasteboard.general.clearContents()
                _ = NSPasteboard.general.setString(text, forType: .string)
                self.reset()
                return
            }
            var insertionTarget = original
            if invocation == .manualRecall, let current = target.currentSnapshot() { insertionTarget = current }
            var transaction = InsertionTransaction(invocation: invocation, target: insertionTarget, selectedItemID: itemID, requestedTier: .directAccessibility, explicitlyConfirmed: true)
            if invocation == .initialTypedMatch || invocation == .clipboardCommand { transaction.target.replacementLocation = 0; transaction.target.replacementLength = self.query.utf16.count; transaction.target.expectedValueDigest = SystemInsertionTarget.digest(self.query) }
            let capability: CompatibilityCapability = AXIsProcessTrusted() ? .full : (CGPreflightPostEventAccess() ? .paste : .copyOnly)
            _ = InsertionCoordinator(target: target).insert(text, transaction: transaction, capability: capability)
            if let itemID { await index.recordSelection(query: self.query, itemID: itemID, appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
            self.session.handle(.explicitlyInserted); self.reset()
        }
    }

    private func focusSnapshot() throws -> AXTargetSnapshot { switch inspector.focusedTarget() { case let .success(value): value; case let .failure(error): throw error } }
    private static func id(_ source: SearchResult.Source) -> String { switch source { case let .saved(id): "saved:\(id)"; case let .clipboard(id): "clipboard:\(id)" } }
    private func validateContext() {
        guard invocation != nil else { return }
        if isAwaitingTypedCommit { return }
        if invocation == .manualRecall, trackedTarget == nil { return }
        guard permission(), let current = target.currentSnapshot(), let trackedTarget, current.processIdentifier == trackedTarget.processIdentifier, current.elementToken == trackedTarget.elementToken else { reset(); health = permission() ? .degraded : .permissionDenied; return }
        if invocation == .manualRecall { guard current.replacementLocation == trackedTarget.replacementLocation, current.replacementLength == trackedTarget.replacementLength else { reset(); return } }
        else { guard current.replacementLocation == query.utf16.count, current.replacementLength == 0, current.expectedValueDigest == SystemInsertionTarget.digest(query) else { reset(); return } }
    }
    private func reset() { generation += 1; isAwaitingTypedCommit = false; session = FreshInputSession(); invocation = nil; trackedTarget = nil; results = []; query.removeAll(keepingCapacity: false); panel.dismiss() }
}

@MainActor private final class RecallPanelController {
    private let panel = KoruPanel(contentRect: .init(x: 0, y: 0, width: 390, height: 260))
    private var navigator = ResultNavigator()
    var onSelect: ((String) -> Void)?
    private var source = "Saved"; private var query = ""
    var isVisible: Bool { panel.isVisible }
    var selectedID: String? { navigator.selectedID }
    init() { panel.contentView = NSHostingView(rootView: AnyView(EmptyView())) }
    func present(rows: [RecallResult], source: String, query: String, caret: CGRect?) { self.source = source; self.query = query; navigator.update(rows); render(source: source, query: query); let screen = NSScreen.screens.first(where: { $0.frame.contains(caret?.origin ?? .zero) }) ?? NSScreen.main; guard let screen else { return }; let placement = CaretPanelPlacer().place(panelSize: panel.frame.size, caretAX: caret, visibleFrame: screen.visibleFrame); panel.setFrameOrigin(placement.origin); panel.orderFrontRegardless() }
    func move(_ delta: Int) { navigator.move(delta); render(source: source, query: query) }
    func dismiss() { navigator.dismiss(); panel.orderOut(nil) }
    private func render(source: String, query: String) { let selected = navigator.selectedID; let action = onSelect; panel.contentView = NSHostingView(rootView: AnyView(RecallPanelView(source: source, query: query, rows: navigator.results, selectedID: selected, select: { action?($0) }))) }
}

private struct RecallPanelView: View {
    let source: String; let query: String; let rows: [RecallResult]; let selectedID: String?; let select: (String) -> Void
    var body: some View { VStack(alignment: .leading, spacing: 8) { HStack { Text(source).font(.headline); Spacer(); Text(query).font(.caption.monospaced()).foregroundStyle(.secondary) }; if rows.isEmpty { Text(source == "Clipboard" ? "Clipboard history is empty" : "No saved matches").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) } else { ForEach(rows) { row in Button { select(row.id) } label: { HStack { VStack(alignment: .leading, spacing: 2) { Text(row.title).lineLimit(1); Text(row.preview).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); if row.id == selectedID { Image(systemName: "return") } }.padding(7).background(row.id == selectedID ? Color.accentColor.opacity(0.18) : .clear).clipShape(RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain).accessibilityLabel("\(row.title), \(row.preview)") } }; Text("↑↓ Navigate   Return Insert   Esc Dismiss").font(.caption2).foregroundStyle(.secondary) }.padding(12).frame(width: 390, height: 260).koruPanelSurface() }
}

private extension View { func koruPanelSurface() -> some View { background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12)) } }
