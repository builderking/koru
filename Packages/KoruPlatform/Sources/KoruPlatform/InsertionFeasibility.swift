import Foundation
import KoruDomain

public enum InsertionDecision: Equatable, Sendable { case rejectUnconfirmed, rejectTargetChanged, attempt(InsertionTier), copyOnly }

public struct InsertionSafetyGate: Sendable {
    public init() {}
    public func decide(transaction: InsertionTransaction, currentTarget: TargetSnapshot?, capability: CompatibilityCapability) -> InsertionDecision {
        guard transaction.explicitlyConfirmed else { return .rejectUnconfirmed }
        guard currentTarget == transaction.target else { return .rejectTargetChanged }
        switch capability {
        case .full: return .attempt(.directAccessibility)
        case .paste: return .attempt(.pasteboardAndPaste)
        case .copyOnly, .paletteOnly: return .copyOnly
        case .blocked: return .rejectTargetChanged
        }
    }
}
