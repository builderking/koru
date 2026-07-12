import Foundation
import KoruDomain
@testable import KoruUI
import SwiftUI
import XCTest

final class ProductFeatureTests: XCTestCase {
    func testContentAndMultipleTagsAreTheOnlyRequiredUserInputs() throws {
        XCTAssertEqual(
            try SavedItemValidation.validatedTriggerTags(content: "Reusable paragraph", triggerTags: ["Dav", "client follow up"]),
            ["Dav", "client follow up"]
        )
        XCTAssertThrowsError(try SavedItemValidation.validatedTriggerTags(content: "Reusable", triggerTags: [])) { error in
            XCTAssertEqual(error as? ProductValidationError, .emptyTags)
        }
        XCTAssertThrowsError(try SavedItemValidation.validatedTriggerTags(content: "Reusable", triggerTags: ["da"])) { error in
            XCTAssertEqual(error as? ProductValidationError, .triggerTagTooShort)
        }
        let maximumLengthTag = String(repeating: "a", count: KoruPolicy.maximumTriggerLength)
        XCTAssertEqual(
            try SavedItemValidation.validatedTriggerTags(content: "Reusable", triggerTags: [maximumLengthTag]),
            [maximumLengthTag]
        )
        XCTAssertThrowsError(
            try SavedItemValidation.validatedTriggerTags(content: "Reusable", triggerTags: [maximumLengthTag + "a"])
        ) { error in
            XCTAssertEqual(error as? ProductValidationError, .triggerTagTooLong)
            XCTAssertEqual(
                error.localizedDescription,
                "Each tag must be at most \(KoruPolicy.maximumTriggerLength) characters."
            )
        }
        XCTAssertThrowsError(try SavedItemValidation.validatedTriggerTags(content: "Reusable", triggerTags: ["clp"])) { error in
            XCTAssertEqual(error as? ProductValidationError, .reservedMatchTerm)
        }
    }

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
        let item = SavedItem(
            title: "",
            behavior: .template,
            plainContent: "Body",
            tags: ["body"],
            templateFields: [.init(token: "legacy", label: "Legacy", order: 0)]
        )
        try store.save(item)
        XCTAssertEqual(store.items[0].title, "Body")
        XCTAssertEqual(store.items[0].behavior, .savedText)
        XCTAssertEqual(store.items[0].tags, ["body"])
        XCTAssertEqual(store.items[0].matchTerms, [.init(value: "body", isPreferredInitialTerm: true, isExactTrigger: true)])
        XCTAssertTrue(store.items[0].templateFields.isEmpty)
        store.move(item.id, to: .recentlyDeleted)
        XCTAssertNotNil(store.items[0].deletedAt)
        store.move(item.id, to: .active)
        XCTAssertEqual(store.items[0].id, item.id)
        var invalid = item; invalid.id = .init(); invalid.tags = ["clp"]
        XCTAssertThrowsError(try store.save(invalid)) { error in
            XCTAssertEqual(error as? ProductValidationError, .reservedMatchTerm)
        }
        invalid.tags = ["duplicate", "DUPLICATE"]
        XCTAssertThrowsError(try store.save(invalid)) { error in
            XCTAssertEqual(error as? ProductValidationError, .duplicateMatchTerm)
        }
        invalid.tags = ["no"]
        XCTAssertThrowsError(try store.save(invalid)) { error in
            XCTAssertEqual(error as? ProductValidationError, .triggerTagTooShort)
        }
        invalid.tags = []
        invalid.matchTerms = []
        XCTAssertThrowsError(try store.save(invalid)) { error in
            XCTAssertEqual(error as? ProductValidationError, .emptyTags)
        }
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

    @MainActor func testWindowReuseCacheSurvivesTheUserClosingAndReopeningAWindow() {
        let cache = WindowReuseCache()
        let size = NSSize(width: 320, height: 200)
        let first = cache.window(key: "library", title: "Koru Library", size: size, view: AnyView(Text("Library")))
        // isReleasedWhenClosed must stay false: the cache keeps a strong reference, and AppKit
        // deallocating a closed window behind the cache's back is a use-after-free on next access.
        XCTAssertFalse(first.isReleasedWhenClosed)
        first.close()
        let second = cache.window(key: "library", title: "Koru Library", size: size, view: AnyView(Text("Library")))
        XCTAssertTrue(first === second)
        XCTAssertEqual(second.title, "Koru Library")
        XCTAssertFalse(cache.window(key: "settings", title: "Koru Settings", size: size, view: AnyView(Text("Settings"))) === first)
    }

    @MainActor func testReloadFromPersistenceRecoversTheLibraryOnceTheVaultOpens() async throws {
        actor VaultGate {
            var isOpen = false
            func open() { isOpen = true }
        }
        struct VaultUnavailable: Error {}
        let gate = VaultGate()
        let persisted = SavedItem(title: "Persisted", behavior: .savedText, plainContent: "Body")
        let store = ProductStore()
        store.configurePersistence(.init(
            load: { guard await gate.isOpen else { throw VaultUnavailable() }; return [persisted] },
            save: { _ in }, move: { _, _ in }, permanentlyDelete: { _ in }, reset: {}
        ))
        // Configuring persistence must not load eagerly: that races the vault unlock and records a
        // spurious repository.load_failed on every launch. The owner reloads once the vault opens.
        XCTAssertEqual(store.diagnosticsSnapshot.repository, .healthy)
        XCTAssertTrue(store.items.isEmpty)
        await store.reloadFromPersistence()
        XCTAssertEqual(store.diagnosticsSnapshot.repository, .degraded)
        XCTAssertTrue(store.items.isEmpty)
        await gate.open()
        await store.reloadFromPersistence()
        XCTAssertEqual(store.items.map(\.title), ["Persisted"])
        XCTAssertTrue(store.items[0].triggerTags.isEmpty)
        XCTAssertEqual(store.diagnosticsSnapshot.repository, .healthy)
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
