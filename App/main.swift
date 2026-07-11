import AppKit
import KoruUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var windows: [String: NSWindow] = [:]
    private let productStore = ProductStore()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Koru")
        let menu = NSMenu()
        menu.addItem(item("Open Recall", #selector(openLibrary), "r"))
        menu.addItem(item("Save Selection", #selector(openLibrary), "s"))
        menu.addItem(.separator())
        menu.addItem(item("Library", #selector(openLibrary)))
        menu.addItem(item("Onboarding", #selector(openOnboarding)))
        menu.addItem(item("Diagnostics", #selector(openDiagnostics)))
        menu.addItem(item("Settings…", #selector(openSettings), ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Koru", #selector(NSApplication.terminate(_:)), "q"))
        statusItem.menu = menu
        NSApp.servicesProvider = self
    }
    private func item(_ title: String, _ action: Selector, _ equivalent: String = "") -> NSMenuItem { let item = NSMenuItem(title: title, action: action, keyEquivalent: equivalent); item.target = self; return item }
    @objc private func openLibrary() { show("library", title: "Koru Library", size: .init(width: 940, height: 620), view: AnyView(LibraryView().environmentObject(productStore))) }
    @objc private func openSettings() { show("settings", title: "Koru Settings", size: .init(width: 680, height: 520), view: AnyView(SettingsView().environmentObject(productStore))) }
    @objc private func openOnboarding() { show("onboarding", title: "Welcome to Koru", size: .init(width: 600, height: 440), view: AnyView(OnboardingView().environmentObject(productStore))) }
    @objc private func openDiagnostics() { show("diagnostics", title: "Koru Diagnostics", size: .init(width: 820, height: 560), view: AnyView(DiagnosticsView().environmentObject(productStore))) }
    private func show(_ key: String, title: String, size: NSSize, view: AnyView) { let window = windows[key] ?? { let w = NSWindow(contentRect: .init(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false); w.title = title; w.contentView = NSHostingView(rootView: view); w.center(); windows[key] = w; return w }(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func saveSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard pasteboard.string(forType: .string) != nil else { error.pointee = "Koru received no supported text."; return }
        openLibrary()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
