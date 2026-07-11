import AppKit
import Carbon
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Koru Disposable Integration Harness"
        let tabs = NSTabView(frame: window.contentView!.bounds); tabs.autoresizingMask = [.width, .height]
        tabs.addTabViewItem(tab("AppKit", appKitControls()))
        tabs.addTabViewItem(tab("SwiftUI", NSHostingView(rootView: SwiftUIHarness())))
        tabs.addTabViewItem(tab("WebKit", webKitControls()))
        tabs.addTabViewItem(tab("Feasibility", feasibilityControls()))
        window.contentView?.addSubview(tabs); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func tab(_ label: String, _ view: NSView) -> NSTabViewItem { let item = NSTabViewItem(); item.label = label; item.view = view; return item }
    private func appKitControls() -> NSView { let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 12; stack.edgeInsets = .init(top: 24, left: 24, bottom: 24, right: 24); [NSTextField(string: ""), NSTextField(string: "Prefilled field"), NSSearchField(string: ""), NSSecureTextField(string: "")].forEach { $0.placeholderString = String(describing: type(of: $0)); stack.addArrangedSubview($0) }; let scroll = NSScrollView(); let text = NSTextView(); text.string = "Editable rich text"; scroll.documentView = text; scroll.hasVerticalScroller = true; stack.addArrangedSubview(scroll); return stack }
    private func webKitControls() -> NSView { let web = WKWebView(); web.loadHTMLString("<label>Input <input></label><br><label>Textarea <textarea></textarea></label><br><div contenteditable='true'>contenteditable</div><label>Password <input type='password'></label>", baseURL: nil); return web }
    private func feasibilityControls() -> NSView { let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 12; stack.edgeInsets = .init(top: 24, left: 24, bottom: 24, right: 24); status.maximumNumberOfLines = 8; stack.addArrangedSubview(status); let axButton = NSButton(title: "Inspect AX Focus/Caret", target: self, action: #selector(probeAX)); stack.addArrangedSubview(axButton); let tapButton = NSButton(title: "Start listen-only Event Tap", target: self, action: #selector(startTap)); stack.addArrangedSubview(tapButton); let hotKey = NSButton(title: "Register global hotkey (Control-Option-K)", target: self, action: #selector(probeHotKey)); stack.addArrangedSubview(hotKey); let paste = NSButton(title: "Inspect Pasteboard", target: self, action: #selector(probePasteboard)); stack.addArrangedSubview(paste); let copy = NSButton(title: "Exercise Tier C Copy-only", target: self, action: #selector(copyFixture)); stack.addArrangedSubview(copy); return stack }
    @objc private func probeAX() { status.stringValue = String(describing: ax.focusedTarget()) }
    @objc private func startTap() { events.start(); status.stringValue = "Event tap requested. Health: \(events.health). No key content is retained." }
    @objc private func probePasteboard() { status.stringValue = String(describing: pasteboard.inspect()) }
    @objc private func probeHotKey() { status.stringValue = "Hotkey registration: \(hotKeys.register(.openKoru, binding: .init(keyCode: 40, modifiers: UInt32(controlKey | optionKey))))" }
    @objc private func copyFixture() { status.stringValue = pasteboard.copyOnly("Koru synthetic insertion fixture") ? "Copied synthetic fixture. Paste manually to complete Tier C." : "Copy failed." }
}
struct SwiftUIHarness: View { @State private var text = ""; @State private var longText = ""; @State private var secret = ""; var body: some View { Form { TextField("Empty SwiftUI field", text: $text); TextEditor(text: $longText).frame(height: 100); SecureField("Secure SwiftUI field", text: $secret); TextField("Read-only", text: .constant("Read-only fixture")).disabled(true) }.padding(24) } }
let app = NSApplication.shared; let delegate = HarnessDelegate(); app.delegate = delegate; app.run()
