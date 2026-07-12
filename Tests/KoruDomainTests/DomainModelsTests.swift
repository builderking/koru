import Foundation
import Testing
@testable import KoruDomain

@Test func savedItemRoundTripsWithStableIdentity() throws {
    let item = SavedItem(title: "Push safely", behavior: .quickReplacement, plainContent: "Synthetic fixture", matchTerms: [.init(value: "pus", isPreferredInitialTerm: true)])
    let data = try JSONEncoder().encode(item)
    #expect(try JSONDecoder().decode(SavedItem.self, from: data) == item)
}

@Test func legacyTagsAndMatchTermsBecomeOneStableTriggerListWithoutChangingTheEncodedShape() throws {
    let item = SavedItem(
        title: "Legacy title",
        behavior: .quickReplacement,
        plainContent: "First useful line\nMore content",
        matchTerms: [.init(value: "Dav"), .init(value: "client follow up")],
        tags: ["dav", "Signature"]
    )
    #expect(item.triggerTags == ["dav", "Signature", "client follow up"])
    #expect(item.displayTitle == "First useful line")
    let decoded = try JSONDecoder().decode(SavedItem.self, from: JSONEncoder().encode(item))
    #expect(decoded.title == "Legacy title")
    #expect(decoded.behavior == .quickReplacement)
    #expect(decoded.triggerTags == item.triggerTags)
}

@Test func legacyClipboardRepresentationsWithoutAThumbnailReferenceStillDecode() throws {
    let legacy = Data(#"{"contentType":"image","byteSize":68}"#.utf8)
    let decoded = try JSONDecoder().decode(ClipboardRepresentation.self, from: legacy)
    #expect(decoded.contentType == .image)
    #expect(decoded.encryptedThumbnailReference == nil)
    #expect(decoded.thumbnailByteSize == nil)
}

@Test func retentionDefaultsKeepClipboardDisabled() {
    #expect(RetentionPolicy.v1Defaults.clipboardHistoryEnabled == false)
    #expect(RetentionPolicy.v1Defaults.maximumEvents == 500)
}

@Test func canonicalBehaviorsAreLocked() { #expect(Set(SavedItemBehavior.allCases) == [.savedText, .quickReplacement, .template]) }
