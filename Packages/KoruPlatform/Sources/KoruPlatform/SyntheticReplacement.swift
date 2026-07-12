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

    public init(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags = []) {
        self.keyCode = keyCode; self.keyDown = keyDown; self.flags = flags
    }
}

/// Replaces the just-typed trigger without relying on the destination's Accessibility text model.
/// Every event is prepared before any Backspace is posted, and the caller-provided PID/generation
/// guard is rechecked before every posted stroke so deletion stops if focus changes mid-sequence.
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
        performReplacement(request: request) { KoruPasteboardOrigin.write(text, to: pasteboard) }
    }

    /// Uses an image or other representation the caller has already placed on this coordinator's
    /// pasteboard, while retaining the identical context-guarded deletion and paste sequence.
    public func replacePreparedPasteboard(request: SyntheticReplacementRequest) -> SyntheticReplacementOutcome {
        performReplacement(request: request) { true }
    }

    private func performReplacement(request: SyntheticReplacementRequest, preparePasteboard: () -> Bool) -> SyntheticReplacementOutcome {
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
        strokes.reserveCapacity(request.deletionCharacterCount * 2 + 2)
        for _ in 0..<request.deletionCharacterCount {
            strokes.append(.init(keyCode: 51, keyDown: true))
            strokes.append(.init(keyCode: 51, keyDown: false))
        }
        strokes.append(.init(keyCode: 9, keyDown: true, flags: .maskCommand))
        strokes.append(.init(keyCode: 9, keyDown: false, flags: .maskCommand))
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
            event.setIntegerValueField(.eventSourceUserData, value: TypedEventTapService.syntheticEventMarker)
            return event
        }
        guard events.count == strokes.count else { return false }
        for event in events {
            guard contextIsValid() else { return false }
            event.post(tap: .cghidEventTap)
        }
        return true
    }
}
