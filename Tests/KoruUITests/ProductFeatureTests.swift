import Foundation
import KoruDomain
@testable import KoruUI
import XCTest

final class ProductFeatureTests: XCTestCase {
    func testTemplateParserPreservesOrderAndRendersRepeatedTokens() throws {
        let fields = [
            TemplateField(token: "name", label: "Name", isRequired: true, order: 0),
            TemplateField(token: "details", label: "Details", order: 1, inputType: .multiline),
        ]
        let definition = TemplateDefinition(content: "Hello {{ name }}. {{details}} / {{name}}", fields: fields)
        XCTAssertEqual(TemplateEngine.tokens(in: definition.content), ["name", "details"])
        XCTAssertEqual(try TemplateEngine.render(definition, values: ["name": "Ari", "details": "Ready"]), "Hello Ari. Ready / Ari")
    }

    func testTemplateRequiresDeclaredRequiredValue() {
        let field = TemplateField(token: "name", label: "Customer name", isRequired: true, order: 0)
        XCTAssertThrowsError(try TemplateEngine.render(.init(content: "Hello {{name}}", fields: [field]), values: [:])) { error in
            XCTAssertEqual(error as? ProductValidationError, .missingRequiredField("Customer name"))
        }
    }

    func testVersionedTransferRoundTripAndDuplicateResolution() throws {
        let original = SavedItem(title: "Reply", behavior: .savedText, plainContent: "Thanks")
        let data = try SavedItemTransfer.encode([original])
        let preview = try SavedItemTransfer.preview(data, existing: [original])
        XCTAssertEqual(preview.duplicateCount, 1)
        XCTAssertTrue(SavedItemTransfer.resolve(preview, existing: [original], resolution: .skip).isEmpty)
        let kept = SavedItemTransfer.resolve(preview, existing: [original], resolution: .keepBoth)
        XCTAssertNotEqual(kept[0].id, original.id)
    }

    func testMalformedImportIsRejectedBeforeMutation() {
        XCTAssertThrowsError(try SavedItemTransfer.preview(Data("{}".utf8), existing: []))
    }

    func testLoggerDropsProhibitedFieldsAndBoundsRetention() async {
        let logger = PrivacySafeLogger(limit: 1)
        await logger.record(.init(category: "test", code: "one", values: ["saved_text": .code("SECRET"), "count": .integer(1)]))
        await logger.record(.init(category: "test", code: "two", values: ["query": .code("PRIVATE")]))
        let events = await logger.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].code, "two")
        XCTAssertNil(events[0].values["query"])
    }

    @MainActor func testLibraryLifecycleRestoresStableIDAndValidatesReservedTerm() throws {
        let store = ProductStore()
        let item = SavedItem(title: "One", behavior: .savedText, plainContent: "Body")
        try store.save(item)
        store.move(item.id, to: .recentlyDeleted)
        XCTAssertNotNil(store.items[0].deletedAt)
        store.move(item.id, to: .active)
        XCTAssertEqual(store.items[0].id, item.id)
        var invalid = item; invalid.id = .init(); invalid.matchTerms = [.init(value: "clp")]
        XCTAssertThrowsError(try store.save(invalid))
    }

    @MainActor func testPermissionControlsDelegateToPlatformWithoutInventingState() {
        let store = ProductStore()
        var requested: KoruPermission?
        var refreshed = false
        store.onPermissionRequested = { requested = $0 }
        store.onPermissionRefreshRequested = { refreshed = true }

        store.request(.accessibility)
        XCTAssertEqual(requested, .accessibility)
        XCTAssertEqual(store.permissionSnapshot.accessibility, .unknown)

        store.refreshPermissions()
        XCTAssertTrue(refreshed)
    }

    func testSupportBundleContainsNoSavedOrClipboardContentFields() throws {
        let permission = PermissionSnapshot(accessibility: .denied, inputListening: .denied, eventPosting: .denied, pasteboard: .granted, loginItem: .unknown, hotKeys: [:])
        let snapshot = DiagnosticsSnapshot(appVersion: "1", osVersion: "test", architecture: "arm64", permissions: permission, eventTap: .stopped, accessibilityObserver: .stopped, pasteboardMonitor: .healthy, repository: .healthy, registeredHotKeys: [:], retainedClipboardCount: 2)
        let text = String(decoding: try SupportBundle(snapshot: snapshot, events: []).data(), as: UTF8.self)
        XCTAssertFalse(text.contains("plainContent"))
        XCTAssertFalse(text.contains("clipboardPayload"))
        XCTAssertFalse(text.contains("query"))
    }
}
