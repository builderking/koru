import AppKit
import CoreGraphics
import Foundation

public struct SyntheticReplacementRequest: Equatable, Sendable {
    public var expectedProcessIdentifier: pid_t
    public var expectedGeneration: Int
    public var expectedElementToken: String?
    public var deletionCharacterCount: Int
    public var explicitlyConfirmed: Bool

    public init(expectedProcessIdentifier: pid_t, expectedGeneration: Int, expectedElementToken: String? = nil, deletionCharacterCount: Int, explicitlyConfirmed: Bool) {
        self.expectedProcessIdentifier = expectedProcessIdentifier
        self.expectedGeneration = expectedGeneration
        self.expectedElementToken = expectedElementToken
        self.deletionCharacterCount = deletionCharacterCount
        self.explicitlyConfirmed = explicitlyConfirmed
    }
}

public enum SyntheticReplacementOutcome: Equatable, Sendable {
    case inserted
    case copied
    case cancelledContextChanged
    case cancelledUnconfirmed
    case failedSafely
}

public struct SyntheticKeyStroke: Equatable, Sendable {
    public var keyCode: CGKeyCode
    public var keyDown: Bool
    public var flags: CGEventFlags
    public var unicodeText: String?

    public init(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags = [], unicodeText: String? = nil) {
        self.keyCode = keyCode; self.keyDown = keyDown; self.flags = flags; self.unicodeText = unicodeText
    }
}

/// Replaces the just-typed trigger without relying on the destination's Accessibility text model.
/// Every event is prepared before any Backspace is posted, and the caller-provided PID/generation
/// guard is rechecked before every posted stroke so deletion stops if focus changes mid-sequence.
/// Text is emitted as Unicode keyboard input rather than Command-V because embedded WebKit hosts
/// are allowed to omit the Edit/Paste command route entirely.
public final class SyntheticReplacementCoordinator: @unchecked Sendable {
    public typealias Context = @Sendable () -> (processIdentifier: pid_t?, generation: Int, focusedElementToken: String?)
    public typealias ContextGuard = @Sendable () -> Bool
    public typealias EventPoster = @Sendable ([SyntheticKeyStroke], ContextGuard) -> Bool

    private let pasteboard: NSPasteboard
    private let canPost: @Sendable () -> Bool
    private let context: Context
    private let post: EventPoster

    public init(
        pasteboard: NSPasteboard = .general,
        canPost: @escaping @Sendable () -> Bool = { CGPreflightPostEventAccess() },
        context: @escaping Context,
        post: @escaping EventPoster = SyntheticReplacementCoordinator.postSystemEvents
    ) {
        self.pasteboard = pasteboard; self.canPost = canPost; self.context = context; self.post = post
    }

    public func replace(_ text: String, request: SyntheticReplacementRequest) -> SyntheticReplacementOutcome {
        performReplacement(request: request, insertionText: text) { KoruPasteboardOrigin.write(text, to: pasteboard) }
    }

    /// Uses an image or other representation the caller has already placed on this coordinator's
    /// pasteboard, while retaining the identical context-guarded deletion and paste sequence.
    public func replacePreparedPasteboard(request: SyntheticReplacementRequest) -> SyntheticReplacementOutcome {
        performReplacement(request: request, insertionText: nil) { true }
    }

    private func performReplacement(request: SyntheticReplacementRequest, insertionText: String?, preparePasteboard: () -> Bool) -> SyntheticReplacementOutcome {
        guard request.explicitlyConfirmed else { return .cancelledUnconfirmed }
        let contextIsValid: ContextGuard = { [context] in
            let current = context()
            guard current.processIdentifier == request.expectedProcessIdentifier,
                  current.generation == request.expectedGeneration else { return false }
            if let expectedElementToken = request.expectedElementToken {
                return current.focusedElementToken == expectedElementToken
            }
            return true
        }
        guard contextIsValid() else { return .cancelledContextChanged }
        guard request.deletionCharacterCount > 0 else { return .failedSafely }

        guard preparePasteboard() else { return .failedSafely }
        guard canPost() else { return .copied }

        var strokes: [SyntheticKeyStroke] = []
        strokes.reserveCapacity(request.deletionCharacterCount * 2 + max(2, (insertionText?.count ?? 0) / 16))
        for _ in 0..<request.deletionCharacterCount {
            strokes.append(.init(keyCode: 51, keyDown: true))
            strokes.append(.init(keyCode: 51, keyDown: false))
        }
        if let insertionText {
            guard !insertionText.isEmpty else { return .failedSafely }
            for chunk in Self.unicodeChunks(insertionText) {
                strokes.append(.init(keyCode: 0, keyDown: true, unicodeText: chunk))
                strokes.append(.init(keyCode: 0, keyDown: false, unicodeText: chunk))
            }
        } else {
            // Non-text representations still require the host's Paste command.
            strokes.append(.init(keyCode: 9, keyDown: true, flags: .maskCommand))
            strokes.append(.init(keyCode: 9, keyDown: false, flags: .maskCommand))
        }
        guard post(strokes, contextIsValid) else {
            return contextIsValid() ? .copied : .cancelledContextChanged
        }
        return .inserted
    }

    public static func postSystemEvents(_ strokes: [SyntheticKeyStroke], contextIsValid: ContextGuard) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        let events = strokes.compactMap { stroke -> CGEvent? in
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: stroke.keyDown) else { return nil }
            event.flags = stroke.flags
            if let unicodeText = stroke.unicodeText {
                var units = Array(unicodeText.utf16)
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            }
            event.setIntegerValueField(.eventSourceUserData, value: TypedEventTapService.syntheticEventMarker)
            return event
        }
        guard events.count == strokes.count else { return false }
        for index in events.indices {
            guard contextIsValid() else { return false }
            events[index].post(tap: .cghidEventTap)
            let stroke = strokes[index]
            if stroke.keyCode == 51, !stroke.keyDown { usleep(3_000) }
            if index + 1 < strokes.count, stroke.unicodeText == nil, strokes[index + 1].unicodeText != nil { usleep(15_000) }
            if stroke.unicodeText != nil { usleep(stroke.keyDown ? 3_000 : 1_000) }
            if stroke.keyCode == 9, stroke.keyDown { usleep(25_000) }
        }
        return true
    }

    static func unicodeChunks(_ text: String, maximumUTF16Count: Int = 32) -> [String] {
        guard maximumUTF16Count > 0 else { return [] }
        var chunks: [String] = []
        var current = ""
        for character in text {
            let addition = String(character)
            if !current.isEmpty, current.utf16.count + addition.utf16.count > maximumUTF16Count {
                chunks.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
