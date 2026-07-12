import AppKit
import Carbon
import KoruDomain
import KoruPlatform
import KoruUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, SaveConfirmationReceiving {
    private static let onboardingCompletedKey = "onboardingCompleted"
    private var statusItem: NSStatusItem!
    private let windows = WindowReuseCache()
    private let productStore = ProductStore()
    private let permissions = PermissionCoordinator()
    private var hotKeys: CarbonHotKeyRegistrar?
    private var lifecycle: IntegrationLifecycle?
    private var serviceProcessor: SelectionServiceProcessor?
    private var pendingSave: SaveConfirmationInput?
    private var pauseItem: NSMenuItem?
    private let hotKeyStore = HotKeyConfigurationStore()
    private let loginItem = LoginItemService()
    private let clipboardSettings = ClipboardSettingsModel()
    private var repository: EncryptedSQLiteRepository?
    private var keyManager: VaultKeyManager?
    private var searchIndex: InMemorySearchIndex?
    private var clipboardController: ClipboardHistoryController?
    private var clipboardMonitor: PasteboardMonitor?
    private var clipboardTimer: Timer?
    private var permissionTimer: Timer?
    private var recallRuntime: RecallRuntime?
    private var typedEvents: TypedEventTapService?
    private var selectionAffordance: SelectionAffordanceMonitor?
    private var retentionPolicy = RetentionPolicy.v1Defaults
    func applicationDidFinishLaunching(_ notification: Notification) {
        if activateExistingInstanceAndTerminate() { return }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Koru")
        let menu = NSMenu()
        menu.addItem(item("Open Recall", #selector(openRecall), "r", modifiers: [.command, .control]))
        menu.addItem(item("Save Selection", #selector(saveSelectionFromMenu), "s", modifiers: [.command, .control]))
        menu.addItem(item("Open Clipboard", #selector(openClipboardRecall), "v", modifiers: [.command, .control]))
        pauseItem = item("Pause Koru", #selector(togglePause)); menu.addItem(pauseItem!)
        menu.addItem(.separator())
        menu.addItem(item("Library", #selector(openLibrary)))
        menu.addItem(item("Onboarding", #selector(openOnboarding)))
        menu.addItem(item("Diagnostics", #selector(openDiagnostics)))
        menu.addItem(item("Settings…", #selector(openSettings), ","))
        menu.addItem(.separator())
        let quitItem = item("Quit Koru", #selector(NSApplication.terminate(_:)), "q"); quitItem.target = NSApp; menu.addItem(quitItem)
        statusItem.menu = menu
        NSApp.servicesProvider = self
        serviceProcessor = SelectionServiceProcessor(receiver: self)
        hotKeys = CarbonHotKeyRegistrar { [weak self] command in DispatchQueue.main.async { self?.dispatch(command) } }
        registerDefaultHotKeys()
        _ = permissions.refresh()
        configureVaultServices()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(lockVaultSession), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(lockVaultSession), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(unlockVaultSession), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(unlockVaultSession), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        if !UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) {
            DispatchQueue.main.async { [weak self] in self?.openOnboarding() }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { permissionTimer?.invalidate(); lifecycle?.transition(.shuttingDown); hotKeys?.unregisterAll() }
    private func item(_ title: String, _ action: Selector, _ equivalent: String = "", modifiers: NSEvent.ModifierFlags = [.command]) -> NSMenuItem { let item = NSMenuItem(title: title, action: action, keyEquivalent: equivalent); item.keyEquivalentModifierMask = equivalent.isEmpty ? [] : modifiers; item.target = self; return item }
    @objc private func openLibrary() { show("library", title: "Koru Library", size: .init(width: 940, height: 620), view: AnyView(LibraryView().environmentObject(productStore))) }
    @objc private func openRecall() { recallRuntime?.openManual(scope: .saved) }
    @objc private func openSettings() { show("settings", title: "Koru Settings", size: .init(width: 680, height: 520), view: AnyView(SettingsView(clipboard: clipboardSettings).environmentObject(productStore))) }
    @objc private func openClipboardRecall() { recallRuntime?.openManual(scope: .clipboard) }
    @objc private func saveSelectionFromMenu() { captureSelection() }
    @objc private func openOnboarding() {
        let onboarding = OnboardingView { [weak self] fullMode in
            guard let self else { return }
            var settings = self.productStore.settings
            settings.typedMatchingEnabled = fullMode
            self.productStore.applySettings(settings)
            UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
        }
        show("onboarding", title: "Welcome to Koru", size: .init(width: 600, height: 440), view: AnyView(onboarding.environmentObject(productStore)))
    }
    @objc private func openDiagnostics() { show("diagnostics", title: "Koru Diagnostics", size: .init(width: 820, height: 560), view: AnyView(DiagnosticsView().environmentObject(productStore))) }
    @objc private func togglePause() { lifecycle?.togglePause(); let paused = lifecycle?.state == .paused; pauseItem?.title = paused ? "Resume Koru" : "Pause Koru"; if paused { lockVaultSession() } else { unlockVaultSession() } }
    private func registerDefaultHotKeys() {
        let defaults: [(HotKeyCommand, HotKeyBinding)] = [(.openKoru, .init(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | controlKey))), (.openClipboard, .init(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | controlKey))), (.saveSelection, .init(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey | controlKey)))]
        defaults.forEach { command, fallback in let binding = hotKeyStore.binding(for: command, fallback: fallback); let state = hotKeys?.register(command, binding: binding) ?? .failed; permissions.setHotKeyState(state, command: String(describing: command)) }
    }
    private func dispatch(_ command: HotKeyCommand) {
        guard lifecycle?.state == .active else { return }
        switch command {
        case .openKoru: recallRuntime?.openManual(scope: .saved)
        case .openClipboard: recallRuntime?.openManual(scope: .clipboard)
        case .saveSelection: captureSelection()
        case .pauseResume: togglePause()
        }
    }
    private func show(_ key: String, title: String, size: NSSize, view: AnyView) { let window = windows.window(key: key, title: title, size: size, view: view); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    private func activateExistingInstanceAndTerminate() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return false }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        guard let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != currentPID && !$0.isTerminated }) else { return false }
        existing.activate(options: [.activateIgnoringOtherApps])
        NSApp.terminate(nil)
        return true
    }
    @objc func saveSelection(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        if let message = serviceProcessor?.process(pasteboard) { error.pointee = message as NSString }
    }
    func receive(_ input: SaveConfirmationInput) {
        pendingSave = input
        productStore.presentDraft(.init(title: String(input.plainText.prefix(48)), behavior: .savedText, plainContent: input.plainText))
        pendingSave = nil
        openLibrary()
    }

    private func captureSelection() {
        let inspector = SystemAccessibilityInspector()
        guard case let .success(snapshot) = inspector.focusedTarget() else { openLibrary(); return }
        let bundleID = NSRunningApplication(processIdentifier: snapshot.processIdentifier)?.bundleIdentifier
        let context = SecurityContext(bundleIdentifier: bundleID, role: snapshot.role, subrole: snapshot.subrole, protectedContent: snapshot.isSecure, editable: snapshot.isEditable)
        let shortcut = SaveSelectionShortcut(reader: SystemSelectedTextReader(), receiver: self)
        if shortcut.invoke(context: SecurityContextClassifier().classify(context)) != .opened { openLibrary() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        clipboardTimer?.invalidate()
        Task { await productStore.flushPersistence(); if let clipboardMonitor { await clipboardMonitor.suspend() }; if let searchIndex { await searchIndex.purge() }; if let repository { await repository.close() }; sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    private func configureVaultServices() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Koru", isDirectory: true)
        let keys = VaultKeyManager(); let repository = EncryptedSQLiteRepository(databaseURL: root.appendingPathComponent("vault.sqlite"), backupDirectory: root.appendingPathComponent("Backups"), keyManager: keys)
        let assets = EncryptedAssetStore(directory: root.appendingPathComponent("Assets"), keyManager: keys); let search = InMemorySearchIndex(); let exclusions = ExclusionPolicy()
        let monitor = PasteboardMonitor(repository: repository, assets: assets, keys: keys, exclusions: exclusions)
        let controller = ClipboardHistoryController(monitor: monitor, repository: repository, search: search, exclusions: exclusions)
        self.repository = repository; keyManager = keys; searchIndex = search; clipboardController = controller; clipboardMonitor = monitor
        let runtime = RecallRuntime(index: search, repository: repository, exclusions: { Set(UserDefaults.standard.stringArray(forKey: "neverObserve") ?? []) })
        let events = TypedEventTapService(enabled: { UserDefaults.standard.bool(forKey: "typedMatchingEnabled") }) { [weak runtime] message in
            guard let runtime else { return false }
            if Thread.isMainThread { return MainActor.assumeIsolated { runtime.receive(message) } }
            return DispatchQueue.main.sync { runtime.receive(message) }
        }
        recallRuntime = runtime; typedEvents = events
        let affordance = SelectionAffordanceMonitor { [weak self] in self?.captureSelection() }
        selectionAffordance = affordance
        productStore.onSettingsChanged = { [weak self] settings in
            if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: "settings") }
            UserDefaults.standard.set(settings.typedMatchingEnabled, forKey: "typedMatchingEnabled")
            UserDefaults.standard.set(settings.neverObserve, forKey: "neverObserve")
            guard let self else { return }
            self.selectionAffordance?.setEnabled(settings.selectionIconEnabled)
            if (self.loginItem.state == .granted) != settings.launchAtLogin { try? self.loginItem.setEnabled(settings.launchAtLogin) }
            if settings.isPaused != (self.lifecycle?.isUserPaused == true) { self.togglePause() }
            if settings.typedMatchingEnabled && !settings.isPaused { self.typedEvents?.start() } else { self.typedEvents?.stopAndPurge() }
            if settings.clipboardHistoryEnabled != self.retentionPolicy.clipboardHistoryEnabled {
                Task { await self.setClipboardEnabled(settings.clipboardHistoryEnabled) }
            }
        }
        productStore.onPermissionRequested = { [weak self] permission in
            guard let self else { return }
            switch permission {
            case .accessibility: self.permissions.requestAccessibility()
            case .inputMonitoring: self.permissions.requestInputListening()
            case .pasteboard: break
            }
            self.refreshRuntimePermissions()
        }
        productStore.onPermissionRefreshRequested = { [weak self] in self?.refreshRuntimePermissions() }
        lifecycle = IntegrationLifecycle(integrations: [runtime, events, affordance]); lifecycle?.install(); lifecycle?.transition(.active)
        if let data = UserDefaults.standard.data(forKey: "settings"),
           var settings = try? JSONDecoder().decode(KoruSettingsSnapshot.self, from: data) {
            if settings.shortcuts == ["Recall": "⌥Space", "Clipboard": "⌥⇧Space", "Save Selection": "⌥⇧S"] {
                settings.shortcuts = KoruSettingsSnapshot().shortcuts
            }
            retentionPolicy.clipboardHistoryEnabled = settings.clipboardHistoryEnabled
            retentionPolicy.maximumAge = Double(settings.retentionDays * 86_400)
            retentionPolicy.maximumEvents = settings.maximumEvents
            retentionPolicy.maximumAssetBytes = settings.maximumAssetMegabytes * 1_024 * 1_024
            productStore.applySettings(settings)
        }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in DispatchQueue.main.async { self?.refreshRuntimePermissions() } }
        productStore.configurePersistence(.init(
            load: { try await repository.savedItems(states: [.active, .archived, .recentlyDeleted]) },
            save: { item in await search.upsert(item); try await repository.save(item) },
            move: { id, collection in
                if collection != .active { await search.remove(savedItemID: id) }
                try await repository.move(id: id, to: collection)
                if collection == .active, let item = try await repository.item(id: id) { await search.upsert(item) }
            },
            permanentlyDelete: { id in await search.remove(savedItemID: id); try await repository.permanentlyDelete(id: id) },
            reset: {
                try await repository.destroyFiles()
                try await assets.removeAll()
                try await keys.removeKey()
                try await repository.open()
            }
        ))
        clipboardSettings.onEnableChanged = { [weak self] enabled in Task { await self?.setClipboardEnabled(enabled) } }
        clipboardSettings.onRetentionChanged = { [weak self] days, count in Task { await self?.setRetention(days: days, count: count) } }
        clipboardSettings.onClear = { [weak self] in Task { await self?.clearClipboard() } }
        clipboardSettings.onExclusionsChanged = { [weak self] ids in Task { await self?.clipboardController?.setNeverSaveClipboardFrom(ids) } }
        clipboardSettings.onObserveExclusionsChanged = { ids in UserDefaults.standard.set(Array(ids).sorted(), forKey: "neverObserve") }
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { await self?.pollClipboard() } }
        Task { await openVaultSession() }
    }
    private func openVaultSession() async { guard let repository, let searchIndex else { return }; do { try await repository.open(); await searchIndex.rebuild(savedItems: try await repository.savedItems(states: [.active]), clipboardEvents: try await repository.clipboardEvents()); try? await clipboardController?.updateRetention(retentionPolicy); await productStore.reloadFromPersistence(); await refreshClipboardSettings() } catch { clipboardSettings.accessDescription = "Vault unavailable" } }
    @objc private func lockVaultSession() { Task { if let clipboardMonitor { await clipboardMonitor.suspend() }; if let searchIndex { await searchIndex.purge() }; if let repository { await repository.close() } } }
    @objc private func unlockVaultSession() { guard lifecycle?.isUserPaused != true else { return }; Task { await openVaultSession(); if let clipboardMonitor { await clipboardMonitor.resume() } } }
    private func setClipboardEnabled(_ enabled: Bool) async { guard retentionPolicy.clipboardHistoryEnabled != enabled else { return }; retentionPolicy.clipboardHistoryEnabled = enabled; try? await clipboardController?.updateRetention(retentionPolicy); await refreshClipboardSettings() }
    private func setRetention(days: Int, count: Int) async { retentionPolicy.maximumAge = Double(days * 86_400); retentionPolicy.maximumEvents = min(count, RetentionPolicy.v1Defaults.maximumEvents); try? await clipboardController?.updateRetention(retentionPolicy); await refreshClipboardSettings() }
    private func clearClipboard() async { try? await clipboardController?.clearHistory(); await refreshClipboardSettings() }
    private func pollClipboard() async { let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier; if (try? await clipboardMonitor?.poll(frontmostBundleID: bundleID)) != nil { await refreshClipboardSettings() } }
    private func refreshClipboardSettings() async { guard let clipboardController else { return }; if let summary = try? await clipboardController.summary() { clipboardSettings.retainedCount = summary.retainedCount; clipboardSettings.encryptedBytes = summary.encryptedBytes }; clipboardSettings.accessDescription = String(describing: await clipboardController.accessState()).capitalized; clipboardSettings.isEnabled = retentionPolicy.clipboardHistoryEnabled; productStore.updatePasteboardHealth(await clipboardMonitor?.isEnabled() == true ? .healthy : .stopped) }
    private func refreshRuntimePermissions() {
        let snapshot = permissions.refresh()
        let eventHealth: ServiceHealth = typedEvents?.health == .running ? .healthy : (typedEvents?.health == .stopped ? .stopped : .unavailable)
        let recallHealth: ServiceHealth = recallRuntime?.health == .ready ? .healthy : (recallRuntime?.health == .stopped ? .stopped : .unavailable)
        productStore.updateRuntimeHealth(permissions: snapshot, eventTap: eventHealth, recall: recallHealth)
        if snapshot.accessibility == .revoked { recallRuntime?.stopAndPurge(); typedEvents?.stopAndPurge(); selectionAffordance?.stopAndPurge() }
        else if snapshot.inputListening == .revoked { typedEvents?.stopAndPurge(); recallRuntime?.start() }
        else if lifecycle?.state == .active { recallRuntime?.start(); typedEvents?.start(); selectionAffordance?.start() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
