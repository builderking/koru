import AppKit
import Carbon
import KoruDomain
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
    private let clipboardSettings = ClipboardSettingsModel()
    private var repository: EncryptedSQLiteRepository?
    private var searchIndex: InMemorySearchIndex?
    private var clipboardController: ClipboardHistoryController?
    private var clipboardMonitor: PasteboardMonitor?
    private var clipboardTimer: Timer?
    private var retentionPolicy = RetentionPolicy.candidate
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
        configureVaultServices()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(lockVaultSession), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(lockVaultSession), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(unlockVaultSession), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(unlockVaultSession), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }
    func applicationWillTerminate(_ notification: Notification) { lifecycle?.transition(.shuttingDown); hotKeys?.unregisterAll() }
    private func item(_ title: String, _ action: Selector, _ equivalent: String = "") -> NSMenuItem { let item = NSMenuItem(title: title, action: action, keyEquivalent: equivalent); item.target = self; return item }
    @objc private func openLibrary() { show("library", title: "Koru Library", size: .init(width: 940, height: 620), view: AnyView(LibraryView().environmentObject(productStore))) }
    @objc private func openSettings() { show("settings", title: "Koru Settings", size: .init(width: 680, height: 520), view: AnyView(SettingsView(clipboard: clipboardSettings).environmentObject(productStore))) }
    @objc private func openClipboardRecall() { openLibrary() }
    @objc private func openOnboarding() { show("onboarding", title: "Welcome to Koru", size: .init(width: 600, height: 440), view: AnyView(OnboardingView().environmentObject(productStore))) }
    @objc private func openDiagnostics() { show("diagnostics", title: "Koru Diagnostics", size: .init(width: 820, height: 560), view: AnyView(DiagnosticsView().environmentObject(productStore))) }
    @objc private func togglePause() { lifecycle?.togglePause(); pauseItem?.title = lifecycle?.state == .paused ? "Resume Koru" : "Pause Koru" }
    private func registerDefaultHotKeys() {
        let defaults: [(HotKeyCommand, HotKeyBinding)] = [(.openKoru, .init(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | controlKey))), (.openClipboard, .init(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | controlKey))), (.saveSelection, .init(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | controlKey)))]
        defaults.forEach { command, fallback in let binding = hotKeyStore.binding(for: command, fallback: fallback); let state = hotKeys?.register(command, binding: binding) ?? .failed; permissions.setHotKeyState(state, command: String(describing: command)) }
    }
    private func dispatch(_ command: HotKeyCommand) { guard lifecycle?.state == .active else { return }; switch command { case .openKoru: openLibrary(); case .openClipboard: openClipboardRecall(); case .saveSelection: openLibrary(); case .pauseResume: togglePause() } }
    private func show(_ key: String, title: String, size: NSSize, view: AnyView) { let window = windows[key] ?? { let w = NSWindow(contentRect: .init(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false); w.title = title; w.contentView = NSHostingView(rootView: view); w.center(); windows[key] = w; return w }(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func saveSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        if let message = serviceProcessor?.process(pasteboard) { error.pointee = message as NSString }
    }
    func receive(_ input: SaveConfirmationInput) { pendingSave = input; openLibrary() }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        clipboardTimer?.invalidate()
        Task { if let clipboardMonitor { await clipboardMonitor.suspend() }; if let searchIndex { await searchIndex.purge() }; if let repository { await repository.close() }; sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    private func configureVaultServices() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Koru", isDirectory: true)
        let keys = VaultKeyManager(); let repository = EncryptedSQLiteRepository(databaseURL: root.appendingPathComponent("vault.sqlite"), backupDirectory: root.appendingPathComponent("Backups"), keyManager: keys)
        let assets = EncryptedAssetStore(directory: root.appendingPathComponent("Assets"), keyManager: keys); let search = InMemorySearchIndex(); let exclusions = ExclusionPolicy()
        let monitor = PasteboardMonitor(repository: repository, assets: assets, keys: keys, exclusions: exclusions)
        let controller = ClipboardHistoryController(monitor: monitor, repository: repository, search: search, exclusions: exclusions)
        self.repository = repository; searchIndex = search; clipboardController = controller; clipboardMonitor = monitor
        clipboardSettings.onEnableChanged = { [weak self] enabled in Task { await self?.setClipboardEnabled(enabled) } }
        clipboardSettings.onRetentionChanged = { [weak self] days, count in Task { await self?.setRetention(days: days, count: count) } }
        clipboardSettings.onClear = { [weak self] in Task { await self?.clearClipboard() } }
        clipboardSettings.onExclusionsChanged = { [weak self] ids in Task { await self?.clipboardController?.setNeverSaveClipboardFrom(ids) } }
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { await self?.pollClipboard() } }
        Task { await openVaultSession() }
    }
    private func openVaultSession() async { guard let repository, let searchIndex else { return }; do { try await repository.open(); await searchIndex.rebuild(savedItems: try await repository.savedItems(states: [.active]), clipboardEvents: try await repository.clipboardEvents()); await refreshClipboardSettings() } catch { clipboardSettings.accessDescription = "Vault unavailable" } }
    @objc private func lockVaultSession() { Task { if let clipboardMonitor { await clipboardMonitor.suspend() }; if let searchIndex { await searchIndex.purge() }; if let repository { await repository.close() } } }
    @objc private func unlockVaultSession() { Task { await openVaultSession(); if let clipboardMonitor { await clipboardMonitor.resume() } } }
    private func setClipboardEnabled(_ enabled: Bool) async { guard retentionPolicy.clipboardHistoryEnabled != enabled else { return }; retentionPolicy.clipboardHistoryEnabled = enabled; try? await clipboardController?.updateRetention(retentionPolicy); await refreshClipboardSettings() }
    private func setRetention(days: Int, count: Int) async { retentionPolicy.maximumAge = Double(days * 86_400); retentionPolicy.maximumEvents = min(count, RetentionPolicy.candidate.maximumEvents); try? await clipboardController?.updateRetention(retentionPolicy); await refreshClipboardSettings() }
    private func clearClipboard() async { try? await clipboardController?.clearHistory(); await refreshClipboardSettings() }
    private func pollClipboard() async { let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier; if (try? await clipboardMonitor?.poll(frontmostBundleID: bundleID)) != nil { await refreshClipboardSettings() } }
    private func refreshClipboardSettings() async { guard let clipboardController else { return }; if let summary = try? await clipboardController.summary() { clipboardSettings.retainedCount = summary.retainedCount; clipboardSettings.encryptedBytes = summary.encryptedBytes }; clipboardSettings.accessDescription = String(describing: await clipboardController.accessState()).capitalized; clipboardSettings.isEnabled = retentionPolicy.clipboardHistoryEnabled }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
