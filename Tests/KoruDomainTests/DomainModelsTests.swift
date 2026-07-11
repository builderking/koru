import Foundation
import Testing
@testable import KoruDomain

@Test func savedItemRoundTripsWithStableIdentity() throws {
    let item = SavedItem(title: "Push safely", behavior: .quickReplacement, plainContent: "Synthetic fixture", matchTerms: [.init(value: "pus", isPreferredInitialTerm: true)])
    let data = try JSONEncoder().encode(item)
    #expect(try JSONDecoder().decode(SavedItem.self, from: data) == item)
}

@Test func retentionDefaultsKeepClipboardDisabled() {
    #expect(RetentionPolicy.v1Defaults.clipboardHistoryEnabled == false)
    #expect(RetentionPolicy.v1Defaults.maximumEvents == 500)
}

@Test func canonicalBehaviorsAreLocked() { #expect(Set(SavedItemBehavior.allCases) == [.savedText, .quickReplacement, .template]) }
