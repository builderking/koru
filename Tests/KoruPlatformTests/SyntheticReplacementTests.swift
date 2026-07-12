import AppKit
import CoreGraphics
import Foundation
@testable import KoruPlatform
import Testing

private final class SyntheticStrokeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [SyntheticKeyStroke] = []
    private let result: Bool

    init(result: Bool = true) { self.result = result }

    func record(_ strokes: [SyntheticKeyStroke]) -> Bool {
        lock.lock()
        stored.append(contentsOf: strokes)
        lock.unlock()
        return result
    }

    var strokes: [SyntheticKeyStroke] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

private final class SyntheticContextBox: @unchecked Sendable {
    typealias Value = (processIdentifier: pid_t?, generation: Int, focusedElementToken: String?)
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }
    func read() -> Value { lock.lock(); defer { lock.unlock() }; return value }
    func update(processIdentifier: pid_t? = nil, generation: Int? = nil, focusedElementToken: String? = nil) {
        lock.lock()
        value = (
            processIdentifier ?? value.processIdentifier,
            generation ?? value.generation,
            focusedElementToken ?? value.focusedElementToken
        )
        lock.unlock()
    }
}

private func replacementPasteboard(_ label: String) -> NSPasteboard {
    let pasteboard = NSPasteboard(name: .init("koru-synthetic-\(label)-\(UUID().uuidString)"))
    pasteboard.clearContents()
    return pasteboard
}

private func replacementRequest(
    processIdentifier: pid_t = 42,
    generation: Int = 7,
    elementToken: String? = nil,
    deletionCharacterCount: Int = 3,
    explicitlyConfirmed: Bool = true
) -> SyntheticReplacementRequest {
    .init(
        expectedProcessIdentifier: processIdentifier,
        expectedGeneration: generation,
        expectedElementToken: elementToken,
        deletionCharacterCount: deletionCharacterCount,
        explicitlyConfirmed: explicitlyConfirmed
    )
}

private struct AutomaticFieldFixture: Sendable, CustomStringConvertible {
    let name: String
    var description: String { name }
}

private let automaticFieldMatrix = [
    AutomaticFieldFixture(name: "AppKit.NSTextField"),
    AutomaticFieldFixture(name: "AppKit.NSSearchField"),
    AutomaticFieldFixture(name: "AppKit.NSTextView"),
    AutomaticFieldFixture(name: "AppKit.NSSecureTextField"),
    AutomaticFieldFixture(name: "SwiftUI.TextField"),
    AutomaticFieldFixture(name: "SwiftUI.TextEditor"),
    AutomaticFieldFixture(name: "SwiftUI.SecureField"),
    AutomaticFieldFixture(name: "WebKit.input-text"),
    AutomaticFieldFixture(name: "WebKit.input-search"),
    AutomaticFieldFixture(name: "WebKit.input-email"),
    AutomaticFieldFixture(name: "WebKit.textarea"),
    AutomaticFieldFixture(name: "WebKit.contenteditable"),
    AutomaticFieldFixture(name: "WebKit.input-password"),
]

@Test(arguments: automaticFieldMatrix)
private func stableFieldMatrixUsesOneHostIndependentGuardedReplacement(fixture: AutomaticFieldFixture) {
    let pasteboard = replacementPasteboard(fixture.name)
    defer { pasteboard.clearContents() }
    let recorder = SyntheticStrokeRecorder()
    let elementToken = "field:\(fixture.name)"
    let coordinator = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (42, 7, elementToken) },
        post: { strokes, contextIsValid in
            guard contextIsValid() else { return false }
            return recorder.record(strokes)
        }
    )

    let outcome = coordinator.replace("Replacement", request: replacementRequest(elementToken: elementToken))

    #expect(outcome == .inserted)
    #expect(recorder.strokes.count == 8)
    #expect(Array(recorder.strokes.suffix(2)) == [
        SyntheticKeyStroke(keyCode: 9, keyDown: true, flags: .maskCommand),
        SyntheticKeyStroke(keyCode: 9, keyDown: false, flags: .maskCommand),
    ])
}

@Test func syntheticReplacementPostsOneBackspacePairPerTriggerCharacterThenCommandV() {
    let pasteboard = replacementPasteboard("sequence")
    defer { pasteboard.clearContents() }
    let recorder = SyntheticStrokeRecorder()
    let coordinator = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (42, 7, nil) },
        post: { strokes, _ in recorder.record(strokes) }
    )

    #expect(coordinator.replace("Replacement paragraph", request: replacementRequest()) == .inserted)

    let strokes = recorder.strokes
    #expect(strokes.count == 8)
    for index in stride(from: 0, to: 6, by: 2) {
        #expect(strokes[index] == SyntheticKeyStroke(keyCode: 51, keyDown: true))
        #expect(strokes[index + 1] == SyntheticKeyStroke(keyCode: 51, keyDown: false))
    }
    #expect(strokes[6] == SyntheticKeyStroke(keyCode: 9, keyDown: true, flags: .maskCommand))
    #expect(strokes[7] == SyntheticKeyStroke(keyCode: 9, keyDown: false, flags: .maskCommand))
    #expect(pasteboard.string(forType: .string) == "Replacement paragraph")
    #expect(pasteboard.string(forType: .init("dev.builderking.koru.origin")) == "dev.builderking.koru")
}

@Test func syntheticReplacementCanPasteAnAlreadyPreparedImageWithoutOverwritingItAsText() {
    let pasteboard = replacementPasteboard("prepared-image")
    defer { pasteboard.clearContents() }
    let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    let image = ClipboardImageContent(originalData: png, thumbnailData: png, format: .png)
    #expect(KoruPasteboardOrigin.writeImage(image, to: pasteboard))
    let recorder = SyntheticStrokeRecorder()
    let coordinator = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (42, 7, "field") },
        post: { strokes, _ in recorder.record(strokes) }
    )

    let outcome = coordinator.replacePreparedPasteboard(
        request: replacementRequest(elementToken: "field")
    )

    #expect(outcome == .inserted)
    #expect(pasteboard.data(forType: .png) == png)
    #expect(pasteboard.string(forType: .string) == nil)
    #expect(recorder.strokes.count == 8)
}

@Test func syntheticReplacementPostsNothingAfterProcessOrGenerationChanges() {
    let pasteboard = replacementPasteboard("changed-context")
    defer { pasteboard.clearContents() }
    pasteboard.setString("sentinel", forType: .string)
    let recorder = SyntheticStrokeRecorder()
    let changedProcess = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (99, 7, nil) },
        post: { strokes, _ in recorder.record(strokes) }
    )
    let changedGeneration = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (42, 8, nil) },
        post: { strokes, _ in recorder.record(strokes) }
    )

    #expect(changedProcess.replace("unsafe", request: replacementRequest()) == .cancelledContextChanged)
    #expect(changedGeneration.replace("unsafe", request: replacementRequest()) == .cancelledContextChanged)
    #expect(recorder.strokes.isEmpty)
    #expect(pasteboard.string(forType: .string) == "sentinel")
}

@Test func syntheticReplacementPostsNothingAfterFocusedElementChangesOrDisappears() {
    let pasteboard = replacementPasteboard("changed-element")
    defer { pasteboard.clearContents() }
    pasteboard.setString("sentinel", forType: .string)
    let recorder = SyntheticStrokeRecorder()
    let changedElement = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (42, 7, "field-b") },
        post: { strokes, _ in recorder.record(strokes) }
    )
    let missingElement = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (42, 7, nil) },
        post: { strokes, _ in recorder.record(strokes) }
    )
    let request = replacementRequest(elementToken: "field-a")

    #expect(changedElement.replace("unsafe", request: request) == .cancelledContextChanged)
    #expect(missingElement.replace("unsafe", request: request) == .cancelledContextChanged)
    #expect(recorder.strokes.isEmpty)
    #expect(pasteboard.string(forType: .string) == "sentinel")
}

@Test func syntheticReplacementStopsRemainingDeletionAndPasteAfterMidSequenceFocusChange() {
    let pasteboard = replacementPasteboard("mid-sequence-focus")
    defer { pasteboard.clearContents() }
    let recorder = SyntheticStrokeRecorder()
    let context = SyntheticContextBox((42, 7, "field-a"))
    let coordinator = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { context.read() },
        post: { strokes, contextIsValid in
            for stroke in strokes {
                guard contextIsValid() else { return false }
                _ = recorder.record([stroke])
                if recorder.strokes.count == 2 {
                    context.update(focusedElementToken: "field-b")
                }
            }
            return true
        }
    )

    let outcome = coordinator.replace(
        "Replacement paragraph",
        request: replacementRequest(elementToken: "field-a")
    )

    #expect(outcome == .cancelledContextChanged)
    #expect(recorder.strokes == [
        SyntheticKeyStroke(keyCode: 51, keyDown: true),
        SyntheticKeyStroke(keyCode: 51, keyDown: false),
    ])
    #expect(!recorder.strokes.contains { $0.keyCode == 9 })
}

@Test func deniedEventPostingCopiesTheReplacementWithoutPostingKeys() {
    let pasteboard = replacementPasteboard("copy-only")
    defer { pasteboard.clearContents() }
    let recorder = SyntheticStrokeRecorder()
    let coordinator = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { false },
        context: { (42, 7, nil) },
        post: { strokes, _ in recorder.record(strokes) }
    )

    #expect(coordinator.replace("Copy me", request: replacementRequest()) == .copied)
    #expect(recorder.strokes.isEmpty)
    #expect(pasteboard.string(forType: .string) == "Copy me")
}

@Test func syntheticReplacementRequiresExplicitConfirmationBeforeClipboardOrKeyboardChanges() {
    let pasteboard = replacementPasteboard("confirmation")
    defer { pasteboard.clearContents() }
    pasteboard.setString("sentinel", forType: .string)
    let recorder = SyntheticStrokeRecorder()
    let coordinator = SyntheticReplacementCoordinator(
        pasteboard: pasteboard,
        canPost: { true },
        context: { (42, 7, nil) },
        post: { strokes, _ in recorder.record(strokes) }
    )

    let request = replacementRequest(explicitlyConfirmed: false)
    #expect(coordinator.replace("unsafe", request: request) == .cancelledUnconfirmed)
    #expect(recorder.strokes.isEmpty)
    #expect(pasteboard.string(forType: .string) == "sentinel")
}

@Test func eventTapTreatsSpacesAsTriggerTextAndControlWhitespaceAsReset() {
    func event(_ text: String) -> CGEvent {
        let source = CGEventSource(stateID: .privateState)!
        let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)!
        var units = Array(text.utf16)
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        return event
    }

    #expect(TypedEventTapService.message(event(" ")) == .character(" "))
    #expect(TypedEventTapService.message(event("\n")) == .reset)
}

@Test func syntheticEventsUseTheDedicatedEventTapMarker() {
    let source = CGEventSource(stateID: .privateState)!
    let event = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)!
    event.setIntegerValueField(.eventSourceUserData, value: TypedEventTapService.syntheticEventMarker)

    #expect(TypedEventTapService.syntheticEventMarker == 0x4B4F5255)
    #expect(event.getIntegerValueField(.eventSourceUserData) == TypedEventTapService.syntheticEventMarker)
}
