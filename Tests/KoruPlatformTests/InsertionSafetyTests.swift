import Testing
import KoruDomain
@testable import KoruPlatform

private let target = TargetSnapshot(processIdentifier: 42, elementToken: "synthetic", replacementLocation: 0, replacementLength: 3, expectedValueDigest: nil)
@Test func insertionRequiresExplicitConfirmation() { let transaction = InsertionTransaction(invocation: .initialTypedMatch, target: target, requestedTier: .directAccessibility); #expect(InsertionSafetyGate().decide(transaction: transaction, currentTarget: target, capability: .full) == .rejectUnconfirmed) }
@Test func changedTargetIsNeverModified() { var transaction = InsertionTransaction(invocation: .manualRecall, target: target, requestedTier: .directAccessibility); transaction.explicitlyConfirmed = true; #expect(InsertionSafetyGate().decide(transaction: transaction, currentTarget: nil, capability: .full) == .rejectTargetChanged) }
@Test(arguments: [(CompatibilityCapability.full, InsertionDecision.attempt(.directAccessibility)), (.paste, .attempt(.pasteboardAndPaste)), (.copyOnly, .copyOnly), (.paletteOnly, .copyOnly)]) func tiersAreDeterministic(input: (CompatibilityCapability, InsertionDecision)) { var transaction = InsertionTransaction(invocation: .manualRecall, target: target, requestedTier: .directAccessibility); transaction.explicitlyConfirmed = true; #expect(InsertionSafetyGate().decide(transaction: transaction, currentTarget: target, capability: input.0) == input.1) }
