import AppKit
import Carbon
import KoruDomain
import KoruPlatform
import KoruUI
import SwiftUI
import WebKit

@MainActor final class HarnessDelegate: NSObject, NSApplicationDelegate {
    private let ax = SystemAccessibilityInspector()
    private let events = EventTapProbe()
    private let pasteboard = PasteboardProbe()
    private let hotKeys = CarbonHotKeyRegistrar()
    private var status = NSTextField(labelWithString: "Select Probe Focus after focusing another field.")
    private var appKitFields: [NSTextField] = []
    private weak var appKitTextView: NSTextView?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Koru Disposable Integration Harness"
        let tabs = NSTabView(frame: window.contentView!.bounds); tabs.autoresizingMask = [.width, .height]
        tabs.addTabViewItem(tab("AppKit", appKitControls()))
        tabs.addTabViewItem(tab("SwiftUI", NSHostingView(rootView: SwiftUIHarness())))
        tabs.addTabViewItem(tab("WebKit", webKitControls()))
        tabs.addTabViewItem(tab("Helpers", NSHostingView(rootView: HelperPreviewHarness())))
        tabs.addTabViewItem(tab("Feasibility", feasibilityControls()))
        window.contentView?.addSubview(tabs); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func tab(_ label: String, _ view: NSView) -> NSTabViewItem { let item = NSTabViewItem(); item.label = label; item.view = view; return item }
    private func appKitControls() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.edgeInsets = .init(top: 24, left: 24, bottom: 24, right: 24)
        stack.addArrangedSubview(NSTextField(labelWithString: "Type a saved tag in each field, choose its suggestion, then verify that only the tag is replaced."))

        let textField = NSTextField(string: "")
        let searchField = NSSearchField(string: "")
        let secureField = NSSecureTextField(string: "")
        [textField, searchField, secureField].forEach {
            $0.placeholderString = "Type a saved tag"
            $0.widthAnchor.constraint(equalToConstant: 520).isActive = true
        }
        appKitFields = [textField, searchField, secureField]
        stack.addArrangedSubview(labeled("NSTextField", control: textField))
        stack.addArrangedSubview(labeled("NSSearchField", control: searchField))

        let scroll = NSScrollView()
        let textView = NSTextView()
        textView.isRichText = true
        scroll.documentView = textView; scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false
        scroll.widthAnchor.constraint(equalToConstant: 520).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
        appKitTextView = textView
        stack.addArrangedSubview(labeled("NSTextView", control: scroll))
        stack.addArrangedSubview(labeled("NSSecureTextField", control: secureField))
        let secureNote = NSTextField(wrappingLabelWithString: "Secure controls may enable macOS Secure Input. While it is active, the OS withholds physical keystrokes from global listeners, so automatic matching cannot start; Koru does not bypass that boundary.")
        secureNote.widthAnchor.constraint(equalToConstant: 520).isActive = true
        stack.addArrangedSubview(secureNote)

        let reset = NSButton(title: "Reset AppKit fields", target: self, action: #selector(resetAppKitFields))
        stack.addArrangedSubview(reset)
        return stack
    }
    private func labeled(_ title: String, control: NSView) -> NSView {
        let group = NSStackView(); group.orientation = .vertical; group.alignment = .leading; group.spacing = 4
        group.addArrangedSubview(NSTextField(labelWithString: title)); group.addArrangedSubview(control)
        return group
    }
    @objc private func resetAppKitFields() { appKitFields.forEach { $0.stringValue = "" }; appKitTextView?.string = ""; appKitFields.first?.window?.makeFirstResponder(appKitFields.first) }
    private func webKitControls() -> NSView {
        let web = WKWebView()
        web.loadHTMLString("""
        <!doctype html><meta charset="utf-8">
        <style>
          body { font: 14px -apple-system; padding: 20px; }
          label { display: block; margin-bottom: 14px; }
          input, textarea, [contenteditable] { box-sizing: border-box; display: block; margin-top: 4px; min-height: 28px; width: 360px; }
          textarea, [contenteditable] { min-height: 72px; }
          [contenteditable] { border: 1px solid #aaa; border-radius: 4px; padding: 5px; }
        </style>
        <p>Type a saved tag in each field, choose its suggestion, then verify that only the tag is replaced.</p>
        <label for="plain-input">input[type=text]<input id="plain-input" type="text" aria-label="WebKit text input" autocomplete="off" spellcheck="false"></label>
        <label for="search-input">input[type=search]<input id="search-input" type="search" aria-label="WebKit search input" autocomplete="off" spellcheck="false"></label>
        <label for="email-input">input[type=email]<input id="email-input" type="email" aria-label="WebKit email input" autocomplete="off" spellcheck="false"></label>
        <label for="textarea">Textarea<textarea id="textarea" aria-label="WebKit textarea" spellcheck="false"></textarea></label>
        <label>Contenteditable<div id="contenteditable" contenteditable="true" role="textbox" aria-label="WebKit contenteditable" spellcheck="false"></div></label>
        <label for="password">Password<input id="password" type="password" aria-label="WebKit password" autocomplete="off"></label>
        <p><small>Password controls may enable macOS Secure Input. While it is active, the OS withholds physical keystrokes from global listeners, so automatic matching cannot start.</small></p>
        <button id="reset-fields" type="button">Reset WebKit fields</button>
        <script>
          document.getElementById('reset-fields').addEventListener('click', () => {
            document.querySelectorAll('input, textarea').forEach((field) => field.value = '');
            document.getElementById('contenteditable').textContent = '';
            document.getElementById('plain-input').focus();
          });
        </script>
        """, baseURL: nil)
        return web
    }
    private func feasibilityControls() -> NSView { let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 12; stack.edgeInsets = .init(top: 24, left: 24, bottom: 24, right: 24); status.maximumNumberOfLines = 8; stack.addArrangedSubview(status); let axButton = NSButton(title: "Inspect AX Focus/Caret", target: self, action: #selector(probeAX)); stack.addArrangedSubview(axButton); let tapButton = NSButton(title: "Start listen-only Event Tap", target: self, action: #selector(startTap)); stack.addArrangedSubview(tapButton); let hotKey = NSButton(title: "Register global hotkey (Control-Option-K)", target: self, action: #selector(probeHotKey)); stack.addArrangedSubview(hotKey); let paste = NSButton(title: "Inspect Pasteboard", target: self, action: #selector(probePasteboard)); stack.addArrangedSubview(paste); let copy = NSButton(title: "Exercise Tier C Copy-only", target: self, action: #selector(copyFixture)); stack.addArrangedSubview(copy); return stack }
    @objc private func probeAX() { status.stringValue = String(describing: ax.focusedTarget()) }
    @objc private func startTap() { events.start(); status.stringValue = "Event tap requested. Health: \(events.health). No key content is retained." }
    @objc private func probePasteboard() { status.stringValue = String(describing: pasteboard.inspect()) }
    @objc private func probeHotKey() { status.stringValue = "Hotkey registration: \(hotKeys.register(.openKoru, binding: .init(keyCode: 40, modifiers: UInt32(controlKey | optionKey))))" }
    @objc private func copyFixture() { status.stringValue = pasteboard.copyOnly("Koru synthetic insertion fixture") ? "Copied synthetic fixture. Paste manually to complete Tier C." : "Copy failed." }
}
struct SwiftUIHarness: View {
    @State private var text = ""
    @State private var longText = ""
    @State private var secret = ""

    var body: some View {
        Form {
            Text("Type a saved tag in each field, choose its suggestion, then verify that only the tag is replaced.")
            TextField("SwiftUI TextField", text: $text)
            VStack(alignment: .leading, spacing: 4) {
                Text("SwiftUI TextEditor")
                TextEditor(text: $longText).frame(height: 110)
            }
            SecureField("SwiftUI SecureField", text: $secret)
            Text("SecureField may enable macOS Secure Input. While it is active, the OS withholds physical keystrokes from global listeners, so automatic matching cannot start.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Reset SwiftUI fields") { text = ""; longText = ""; secret = "" }
        }
        .padding(24)
    }
}

struct HelperPreviewHarness: View {
    private let savedRows = [
        RecallResult(
            id: "saved-preview",
            title: "Saved text",
            preview: "Hi Maia — great talking today. I’ll send the agreement tomorrow."
        ),
    ]
    private let clipboardRows: [RecallResult]

    init() {
        let iconData = NSApplication.shared.applicationIconImage.tiffRepresentation
        clipboardRows = [
            RecallResult(id: "clipboard-text", title: "Text", preview: "Q3 numbers summary copied a moment ago"),
            RecallResult(id: "clipboard-image", title: "Image", preview: "Koru app artwork", contentType: .image, thumbnailData: iconData),
            RecallResult(id: "clipboard-link", title: "Link", preview: "https://koru.builderking.io"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Exact helper surfaces used by Koru").font(.headline)
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("One saved match · adaptive height").font(.caption).foregroundStyle(.secondary)
                    RecallPanelContentView(
                        source: "Saved",
                        query: "dav",
                        rows: savedRows,
                        selectedID: savedRows.first?.id,
                        notice: nil,
                        select: { _ in }
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clipboard · text and real thumbnail").font(.caption).foregroundStyle(.secondary)
                    RecallPanelContentView(
                        source: "Clipboard",
                        query: KoruPolicy.reservedClipboardCommand,
                        rows: clipboardRows,
                        selectedID: clipboardRows.first?.id,
                        notice: nil,
                        select: { _ in }
                    )
                }
            }
            Spacer()
        }
        .padding(28)
    }
}
let app = NSApplication.shared; let delegate = HarnessDelegate(); app.delegate = delegate; app.run()
