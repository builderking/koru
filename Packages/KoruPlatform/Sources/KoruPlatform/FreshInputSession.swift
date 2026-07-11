import Foundation
import KoruDomain

public enum FreshInputState: Equatable, Sendable { case unknown, eligibleEmptyStart, trackingPrefix(String), panelVisible(String), ineligibleUntilFocusChanges, completedOrDismissed }
public enum FreshInputEvent: Equatable, Sendable {
    case focus(value: String?, selectionLocation: Int?, selectionLength: Int?, editable: Bool, secure: Bool, excluded: Bool)
    case committedCharacter(Character, hasQualifyingMatch: Bool)
    case validate(value: String?, caretLocation: Int?, selectionLength: Int?)
    case paste, caretMoved, selectionChanged, compositionBegan, focusLost, dismiss, explicitlyInserted, tabTransfer
}

public struct FreshInputSession: Sendable {
    public private(set) var state: FreshInputState = .unknown
    public init() {}
    public mutating func handle(_ event: FreshInputEvent) {
        switch event {
        case let .focus(value, location, length, editable, secure, excluded):
            state = editable && !secure && !excluded && value == "" && location == 0 && length == 0 ? .eligibleEmptyStart : .ineligibleUntilFocusChanges
        case let .committedCharacter(character, match):
            guard !character.isWhitespace else { state = .ineligibleUntilFocusChanges; return }
            let prefix: String
            switch state { case .eligibleEmptyStart: prefix = String(character); case let .trackingPrefix(current): prefix = current + String(character); default: return }
            state = (match || prefix == KoruPolicy.reservedClipboardCommand) ? .panelVisible(prefix) : .trackingPrefix(prefix)
        case .focusLost: state = .unknown
        case .dismiss, .explicitlyInserted: state = .completedOrDismissed
        case .paste, .caretMoved, .selectionChanged, .compositionBegan: state = .ineligibleUntilFocusChanges
        case let .validate(value, caret, length):
            let prefix: String?
            switch state { case let .trackingPrefix(value), let .panelVisible(value): prefix = value; default: prefix = nil }
            guard let prefix, value == prefix, caret == prefix.utf16.count, length == 0 else { state = .ineligibleUntilFocusChanges; return }
        case .tabTransfer:
            break // The tracked target prefix is frozen; panel search owns subsequent input.
        }
    }
}
