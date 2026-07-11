import AppKit
import Carbon
import KoruPlatform
import KoruUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, SaveConfirmationReceiving {
    private var statusItem: NSStatusItem!
    private var windows: [String: NSWindow] = [:]
    private let productStore = ProductStore()
    private let permissions = PermissionCoordinator()
    private var hotKeys: CarbonHotKeyRegistrar?
    private var lifecycle: IntegrationLifecycle?
    private var serviceProcessor: SelectionServiceProcessor?
    private var pendingSave: SaveConfirmationInput?
    private var pauseItem: NSMenuItem?
    private let hotKeyStore = HotKeyConfigurationStore()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Koru")
        let menu = NSMenu()
        menu.addItem(item("Open Recall", #selector(openLibrary), "r"))
        menu.addItem(item("Save Selection", #selector(openLibrary), "s"))
        pauseItem = item("Pause Koru", #selector(togglePause)); menu.addItem(pauseItem!)
        menu.addItem(.separator())
        menu.addItem(item("Library", #selector(openLibrary)))
        menu.addItem(item("Onboarding", #selector(openOnboarding)))
        menu.addItem(item("Diagnostics", #selector(openDiagnostics)))
        menu.addItem(item("Settings…", #selector(openSettings), ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Koru", #selector(NSApplication.terminate(_:)), "q"))
        statusItem.menu = menu
        NSApp.servicesProvider = self
        serviceProcessor = SelectionServiceProcessor(receiver: self)
        hotKeys = CarbonHotKeyRegistrar { [weak self] command in DispatchQueue.main.async { self?.dispatch(command) } }
        registerDefaultHotKeys()
        lifecycle = IntegrationLifecycle(integrations: [])
        lifecycle?.install()
        _ = permissions.refresh()
    }
    func applicationWillTerminate(_ notification: Notification) { lifecycle?.transition(.shuttingDown); hotKeys?.unregisterAll() }
    private func item(_ title: String, _ action: Selector, _ equivalent: String = "") -> NSMenuItem { let item = NSMenuItem(title: title, action: action, keyEquivalent: equivalent); item.target = self; return item }
    @objc private func openLibrary() { show("library", title: "Koru Library", size: .init(width: 940, height: 620), view: AnyView(LibraryView().environmentObject(productStore))) }
    @objc private func openSettings() { show("settings", title: "Koru Settings", size: .init(width: 680, height: 520), view: AnyView(SettingsView().environmentObject(productStore))) }
    @objc private func openOnboarding() { show("onboarding", title: "Welcome to Koru", size: .init(width: 600, height: 440), view: AnyView(OnboardingView().environmentObject(productStore))) }
    @objc private func openDiagnostics() { show("diagnostics", title: "Koru Diagnostics", size: .init(width: 820, height: 560), view: AnyView(DiagnosticsView().environmentObject(productStore))) }
    @objc private func togglePause() { lifecycle?.togglePause(); pauseItem?.title = lifecycle?.state == .paused ? "Resume Koru" : "Pause Koru" }
    private func registerDefaultHotKeys() {
        let defaults: [(HotKeyCommand, HotKeyBinding)] = [(.openKoru, .init(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | controlKey))), (.openClipboard, .init(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | controlKey))), (.saveSelection, .init(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | controlKey)))]
        defaults.forEach { command, fallback in let binding = hotKeyStore.binding(for: command, fallback: fallback); let state = hotKeys?.register(command, binding: binding) ?? .failed; permissions.setHotKeyState(state, command: String(describing: command)) }
    }
    private func dispatch(_ command: HotKeyCommand) { guard lifecycle?.state == .active else { return }; switch command { case .openKoru, .openClipboard: openLibrary(); case .saveSelection: openLibrary(); case .pauseResume: togglePause() } }
    private func show(_ key: String, title: String, size: NSSize, view: AnyView) { let window = windows[key] ?? { let w = NSWindow(contentRect: .init(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false); w.title = title; w.contentView = NSHostingView(rootView: view); w.center(); windows[key] = w; return w }(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func saveSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        if let message = serviceProcessor?.process(pasteboard) { error.pointee = message as NSString }
    }
    func receive(_ input: SaveConfirmationInput) { pendingSave = input; openLibrary() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
