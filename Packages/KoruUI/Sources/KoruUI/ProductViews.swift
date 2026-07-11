import AppKit
import KoruDomain
import SwiftUI

private extension SavedItemBehavior {
    var label: String { switch self { case .savedText: "Saved text"; case .quickReplacement: "Quick replacement"; case .template: "Template" } }
    var symbol: String { switch self { case .savedText: "text.quote"; case .quickReplacement: "bolt"; case .template: "character.cursor.ibeam" } }
}
private extension SavedItemCollection {
    var label: String { switch self { case .active: "Saved"; case .archived: "Archive"; case .recentlyDeleted: "Recently Deleted" } }
    var symbol: String { switch self { case .active: "bookmark"; case .archived: "archivebox"; case .recentlyDeleted: "trash" } }
}

public struct OnboardingView: View {
    @EnvironmentObject private var store: ProductStore
    @State private var step = 0
    @State private var mode = 0
    private let onComplete: (Bool) -> Void
    public init(onComplete: @escaping (Bool) -> Void = { _ in }) { self.onComplete = onComplete }
    public var body: some View {
        VStack(spacing: KoruSpacing.section) {
            HStack { Text("Welcome to Koru").font(.title2.bold()); Spacer(); Text("\(step + 1) of 4").foregroundStyle(.secondary) }
            Group {
                if step == 0 { valueDemo }
                else if step == 1 { modeChoice }
                else if step == 2 { permissionChoice }
                else { finish }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack { if step > 0 { Button("Back") { step -= 1 } }; Spacer(); if step < 3 { Button("Continue") { step += 1 }.keyboardShortcut(.defaultAction) } else { Button("Done") { onComplete(mode == 1); NSApp.keyWindow?.close() }.keyboardShortcut(.defaultAction) } }
        }.padding(28).frame(minWidth: 560, idealWidth: 600, minHeight: 390)
    }
    private var valueDemo: some View { VStack(spacing: 14) { Image(systemName: "text.bubble").font(.system(size: 42)); Text("Remember a fragment. Find the right writing.").font(.title3); Text("Your Library works immediately—without permissions, an account, or a network connection.").foregroundStyle(.secondary); HStack { Text("pus").font(.system(.body, design: .monospaced)); Image(systemName: "arrow.right"); Label("Push changes and open a pull request", systemImage: "text.quote") }.padding().koruAdaptiveSurface() }.multilineTextAlignment(.center).accessibilityElement(children: .combine) }
    private var modeChoice: some View { VStack(alignment: .leading, spacing: 12) { Text("Choose how Koru appears").font(.headline); Picker("Mode", selection: $mode) { Text("Hotkey-only").tag(0); Text("Full").tag(1) }.pickerStyle(.segmented); GroupBox { VStack(alignment: .leading, spacing: 8) { Label(mode == 0 ? "Open recall with a shortcut" : "Also match fragments at the start of a fresh empty field", systemImage: "keyboard"); Text(mode == 0 ? "No Input Monitoring needed. You can enable more later." : "Full mode needs Accessibility and Input Monitoring. Koru ignores secure fields and configured apps.").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) } }.frame(maxWidth: 460) }
    private var permissionChoice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enable only what you want").font(.headline)
            if mode == 1 {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Lets Koru verify a safe editable field and insert only after you choose a result.",
                    state: store.permissionSnapshot.accessibility
                ) { store.request(.accessibility) }
                PermissionRow(
                    title: "Input Monitoring",
                    detail: "Lets Koru see only the small live prefix needed for typed matching. Raw keystrokes are never stored.",
                    state: store.permissionSnapshot.inputListening
                ) { store.request(.inputMonitoring) }
                if store.permissionSnapshot.inputListening != .granted {
                    Text("If Input Monitoring is enabled in System Settings but still shows Denied, quit and reopen Koru after changing the toggle.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Label("Hotkey-only mode does not require Input Monitoring. Accessibility is requested only when Koru needs to insert into another app.", systemImage: "keyboard")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Toggle("Enable Clipboard History", isOn: Binding(
                get: { store.settings.clipboardHistoryEnabled },
                set: { enabled in var settings = store.settings; settings.clipboardHistoryEnabled = enabled; store.applySettings(settings) }
            ))
            Text("Clipboard History is not a macOS permission. It is off by default; when enabled, recent copies are encrypted locally and expire automatically.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Refresh Permission Status") { store.refreshPermissions() }
                .accessibilityHint("Checks current macOS permission status again")
        }.frame(maxWidth: 500)
    }
    private var finish: some View { VStack(spacing: 14) { Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(.green); Text("Koru is ready").font(.title3); Text("Declined permissions never block the Library. Use the recall hotkey now and revisit Settings whenever you want.").foregroundStyle(.secondary).multilineTextAlignment(.center); Label("Content stays local. Secure contexts are ignored.", systemImage: "lock.shield") } }
}

private struct PermissionRow: View {
    var title: String; var detail: String; var state: PermissionState; var action: () -> Void
    var body: some View { GroupBox { HStack(alignment: .top) { VStack(alignment: .leading, spacing: 4) { HStack { Text(title).bold(); Text(state.rawValue.capitalized).font(.caption).padding(.horizontal, 6).background(.quaternary).clipShape(Capsule()) }; Text(detail).font(.callout).foregroundStyle(.secondary) }; Spacer(); Button("Review & Enable", action: action) }.frame(maxWidth: .infinity) } }
}

public struct TemplateCompletionView: View {
    public var item: SavedItem
    public var insert: (String) -> Void
    public var cancel: () -> Void
    @State private var values: [String: String] = [:]
    @State private var error: String?
    public init(item: SavedItem, insert: @escaping (String) -> Void, cancel: @escaping () -> Void) { self.item = item; self.insert = insert; self.cancel = cancel }
    public var body: some View { VStack(alignment: .leading, spacing: 12) { HStack { Label(item.title, systemImage: "character.cursor.ibeam").font(.headline); Spacer(); Text("Nothing changes until Insert").font(.caption).foregroundStyle(.secondary) }; ForEach(item.templateFields.sorted(by: { $0.order < $1.order })) { field in VStack(alignment: .leading, spacing: 4) { Text(field.label + (field.isRequired ? " *" : "")); if field.inputType == .multiline { TextEditor(text: binding(field)).frame(height: 72) } else { TextField(field.helpText ?? "", text: binding(field)) }; if let help = field.helpText { Text(help).font(.caption).foregroundStyle(.secondary) } } }; if let error { Text(error).foregroundStyle(.red).accessibilityLabel("Error: \(error)") }; HStack { Button("Cancel", action: cancel).keyboardShortcut(.cancelAction); Spacer(); Button("Insert") { do { insert(try TemplateEngine.render(.init(content: item.plainContent, fields: item.templateFields), values: values)) } catch { self.error = error.localizedDescription } }.keyboardShortcut(.defaultAction) } }.padding(16).frame(width: 430).koruAdaptiveSurface() }
    private func binding(_ field: TemplateField) -> Binding<String> { Binding(get: { values[field.token] ?? field.defaultValue ?? "" }, set: { values[field.token] = $0 }) }
}

public struct SavedItemEditor: View {
    @EnvironmentObject private var store: ProductStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SavedItem
    @State private var tagsText: String
    @State private var matchText: String
    @State private var error: String?
    public var duplicateWarning: Bool
    public init(item: SavedItem = SavedItem(title: "", behavior: .savedText, plainContent: ""), duplicateWarning: Bool = false) { _draft = State(initialValue: item); _tagsText = State(initialValue: item.tags.joined(separator: ", ")); _matchText = State(initialValue: item.matchTerms.map(\.value).joined(separator: ", ")); self.duplicateWarning = duplicateWarning }
    public var body: some View { VStack(alignment: .leading, spacing: 12) { Text(draft.title.isEmpty ? "Save to Koru" : "Edit Saved Item").font(.title2); if duplicateWarning { Label("Similar content already exists. Review before saving another copy.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }; TextField("Title", text: $draft.title); Picker("Behavior", selection: $draft.behavior) { ForEach(SavedItemBehavior.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented); Text("Content").font(.headline); TextEditor(text: $draft.plainContent).font(.body).frame(minHeight: 150).overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator)); TextField("Tags, separated by commas", text: $tagsText); if draft.behavior == .quickReplacement { TextField("Match terms, separated by commas", text: $matchText) }; if draft.behavior == .template { TemplateFieldsEditor(content: $draft.plainContent, fields: $draft.templateFields) }; if let error { Text(error).foregroundStyle(.red) }; HStack { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Save") { save() }.keyboardShortcut(.defaultAction) } }.padding(20).frame(minWidth: 520, minHeight: 500) }
    private func save() { draft.tags = split(tagsText); draft.matchTerms = split(matchText).map { MatchTerm(value: $0, isPreferredInitialTerm: true) }; draft.updatedAt = .now; do { if draft.behavior == .template { try TemplateEngine.validate(.init(content: draft.plainContent, fields: draft.templateFields)) }; try store.save(draft); dismiss() } catch { self.error = error.localizedDescription } }
    private func split(_ value: String) -> [String] { Array(Set(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted() }
}

private struct TemplateFieldsEditor: View {
    @Binding var content: String; @Binding var fields: [TemplateField]
    var body: some View { GroupBox("Template fields") { VStack(alignment: .leading, spacing: 8) { ForEach($fields) { $field in HStack { TextField("token", text: $field.token).frame(width: 100); TextField("Label", text: $field.label); Toggle("Required", isOn: $field.isRequired); Picker("Type", selection: $field.inputType) { Text("Line").tag(TemplateField.InputType.singleLine); Text("Multi").tag(TemplateField.InputType.multiline) }.labelsHidden().frame(width: 80); Button { fields.removeAll { $0.id == field.id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove \(field.label)") } }; Button("Add field") { let index = fields.count + 1; let token = "value\(index)"; fields.append(.init(token: token, label: "Value \(index)", order: index)); if !content.isEmpty { content += " " }; content += "{{\(token)}}" } }.padding(6) } }
}

public struct LibraryView: View {
    @EnvironmentObject private var store: ProductStore
    @State private var collection = SavedItemCollection.active
    @State private var query = ""
    @State private var selection: SavedItemID?
    @State private var editor: SavedItem?
    @State private var confirmDelete: SavedItem?
    @State private var transferMessage: String?
    public init() {}
    private var filtered: [SavedItem] { store.items.filter { item in let belongs = collection == .recentlyDeleted ? item.deletedAt != nil : collection == .archived ? item.deletedAt == nil && item.archivedAt != nil : item.deletedAt == nil && item.archivedAt == nil; let matches = query.isEmpty || item.title.localizedCaseInsensitiveContains(query) || item.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) }) || item.plainContent.localizedCaseInsensitiveContains(query); return belongs && matches }.sorted { ($0.isPinned ? 0 : 1, $0.title.lowercased()) < ($1.isPinned ? 0 : 1, $1.title.lowercased()) } }
    public var body: some View {
        NavigationSplitView {
            List(selection: $collection) {
                ForEach(SavedItemCollection.allCases, id: \.self) { destination in
                    Label(destination.label, systemImage: destination.symbol).tag(destination)
                }
            }.navigationTitle("Koru")
        } content: {
            List(selection: $selection) { ForEach(filtered) { item in itemRow(item) } }
                .searchable(text: $query, prompt: "Search title, content, or tags")
                .navigationTitle(collection.label)
                .toolbar { ToolbarItemGroup { newButton; transferMenu } }
        } detail: {
            if let item = store.items.first(where: { $0.id == selection }) { detail(item) }
            else { Text("No saved item selected").foregroundStyle(.secondary) }
        }
        .sheet(item: $editor) { SavedItemEditor(item: $0).environmentObject(store) }
        .onReceive(store.$pendingDraft.compactMap { $0 }) { draft in
            editor = draft
            store.pendingDraft = nil
        }
        .alert("Permanently delete this item?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { if let item = confirmDelete { store.permanentlyDelete(item.id) } }
        } message: { Text("This removes the item and its owned assets. This cannot be undone.") }
        .alert("Import / Export", isPresented: Binding(get: { transferMessage != nil }, set: { if !$0 { transferMessage = nil } })) { Button("OK") {} } message: { Text(transferMessage ?? "") }
    }
    private func itemRow(_ item: SavedItem) -> some View {
        HStack { Image(systemName: item.behavior.symbol); VStack(alignment: .leading) { Text(item.title).lineLimit(1); Text(item.tags.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); if item.isPinned { Image(systemName: "pin.fill").accessibilityLabel("Pinned") } }
            .tag(item.id).contextMenu { itemMenu(item) }.accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.title), \(item.behavior.label)\(item.isPinned ? ", pinned" : "")")
    }
    private var newButton: some View { Button { editor = SavedItem(title: "", behavior: .savedText, plainContent: "") } label: { Label("New", systemImage: "plus") }.keyboardShortcut("n") }
    private var transferMenu: some View { Menu { Button("Import…", action: importItems); Button("Export Saved…", action: exportItems) } label: { Label("Transfer", systemImage: "square.and.arrow.up.on.square") } }
    @ViewBuilder private func detail(_ item: SavedItem) -> some View { ScrollView { VStack(alignment: .leading, spacing: 16) { HStack { Label(item.behavior.label, systemImage: item.behavior.symbol); Spacer(); Button("Edit") { editor = item }.keyboardShortcut(.return, modifiers: [.command]) }; Text(item.title).font(.title2.bold()); if !item.tags.isEmpty { HStack { ForEach(item.tags, id: \.self) { Text($0).font(.caption).padding(.horizontal, 7).padding(.vertical, 3).background(.quaternary).clipShape(Capsule()) } } }; Text(item.plainContent).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8)); if item.behavior == .quickReplacement { LabeledContent("Match terms", value: item.matchTerms.map(\.value).joined(separator: ", ")) }; if item.behavior == .template { LabeledContent("Fields", value: item.templateFields.map(\.label).joined(separator: ", ")) } }.padding(24) } }
    @ViewBuilder private func itemMenu(_ item: SavedItem) -> some View { Button("Edit") { editor = item }; Button("Duplicate") { var copy = item; copy.id = .init(); copy.title += " copy"; copy.createdAt = .now; copy.updatedAt = .now; editor = copy }; Button(item.isPinned ? "Unpin" : "Pin") { var copy = item; copy.isPinned.toggle(); try? store.save(copy) }; Divider(); if collection == .active { Button("Archive") { store.move(item.id, to: .archived) } }; if collection != .active { Button("Restore") { store.move(item.id, to: .active) } }; if collection != .recentlyDeleted { Button("Move to Recently Deleted", role: .destructive) { store.move(item.id, to: .recentlyDeleted) } } else { Button("Delete Permanently", role: .destructive) { confirmDelete = item } } }
    private func exportItems() { let panel = NSSavePanel(); panel.nameFieldStringValue = "Koru Saved Items.json"; panel.allowedContentTypes = [.json]; panel.begin { response in guard response == .OK, let url = panel.url else { return }; do { try SavedItemTransfer.encode(store.items.filter { $0.deletedAt == nil }).write(to: url, options: .atomic); transferMessage = "Saved items exported as plaintext JSON. Keep the file private." } catch { transferMessage = error.localizedDescription } } }
    private func importItems() { let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false; panel.begin { response in guard response == .OK, let url = panel.url else { return }; do { let preview = try SavedItemTransfer.preview(Data(contentsOf: url), existing: store.items); let imported = SavedItemTransfer.resolve(preview, existing: store.items, resolution: .keepBoth); try imported.forEach(store.save); transferMessage = "Imported \(imported.count) item(s). \(preview.duplicateCount) duplicate(s) were kept as copies." } catch { transferMessage = error.localizedDescription } } }
}

public struct SettingsView: View {
    @EnvironmentObject private var store: ProductStore
    @ObservedObject private var clipboard: ClipboardSettingsModel
    @State private var draft = KoruSettingsSnapshot()
    @State private var newObserve = ""; @State private var newClipboard = ""; @State private var confirmReset = false
    public init(clipboard: ClipboardSettingsModel = .init()) { self.clipboard = clipboard }
    public var body: some View { TabView { Form { Toggle("Typed Matching", isOn: $draft.typedMatchingEnabled); Text("Matches only at the start of a verified fresh empty field.").font(.caption).foregroundStyle(.secondary); Toggle("Selection save icon", isOn: $draft.selectionIconEnabled); Toggle("Launch at Login", isOn: $draft.launchAtLogin); Toggle("Pause Koru", isOn: $draft.isPaused); shortcuts }.tabItem { Label("General", systemImage: "gear") }; Form { Toggle("Clipboard History", isOn: $draft.clipboardHistoryEnabled); LabeledContent("Pasteboard access", value: clipboard.accessDescription); Stepper("Retention: \(draft.retentionDays) days", value: $draft.retentionDays, in: 1...30); Stepper("Maximum events: \(draft.maximumEvents)", value: $draft.maximumEvents, in: 50...500, step: 50); LabeledContent("Retained", value: "\(clipboard.retainedCount) events"); LabeledContent("Encrypted storage", value: ByteCountFormatter.string(fromByteCount: Int64(clipboard.encryptedBytes), countStyle: .file)); Stepper("Asset limit: \(draft.maximumAssetMegabytes) MB", value: $draft.maximumAssetMegabytes, in: 32...1024, step: 32); exclusionEditor("Never Observe", value: $newObserve, items: $draft.neverObserve); exclusionEditor("Never Save Clipboard From", value: $newClipboard, items: $draft.neverSaveClipboardFrom) }.tabItem { Label("Privacy", systemImage: "hand.raised") }; Form { ForEach(KoruPermission.allCases, id: \.self) { permission in HStack { Text(permission.rawValue.capitalized); Spacer(); Text(permissionState(permission).rawValue.capitalized); Button("Review") { store.request(permission) } } }; Button("Refresh Permission State") { store.refreshPermissions() }; Divider(); Button("Clear Clipboard History") { clipboard.onClear?(); Task { _ = await store.perform(.clearClipboardHistory) } }; Button("Reset Vault…", role: .destructive) { confirmReset = true } }.tabItem { Label("Permissions", systemImage: "lock.shield") } }.padding().frame(minWidth: 620, minHeight: 470).onAppear { draft = store.settings }.onChange(of: draft) { value in store.applySettings(value); clipboard.onEnableChanged?(value.clipboardHistoryEnabled); clipboard.onRetentionChanged?(value.retentionDays, value.maximumEvents); clipboard.onExclusionsChanged?(Set(value.neverSaveClipboardFrom)); clipboard.onObserveExclusionsChanged?(Set(value.neverObserve)) }.alert("Reset the entire vault?", isPresented: $confirmReset) { Button("Cancel", role: .cancel) {}; Button("Reset Vault", role: .destructive) { Task { _ = await store.perform(.resetVault) } } } message: { Text("All saved items and clipboard history will be permanently deleted.") } }
    private var shortcuts: some View { Section("Shortcuts") { ForEach(draft.shortcuts.keys.sorted(), id: \.self) { key in TextField(key, text: Binding(get: { draft.shortcuts[key] ?? "" }, set: { draft.shortcuts[key] = $0 })) } } }
    private func permissionState(_ permission: KoruPermission) -> PermissionState { switch permission { case .accessibility: store.permissionSnapshot.accessibility; case .inputMonitoring: store.permissionSnapshot.inputListening; case .pasteboard: store.permissionSnapshot.pasteboard } }
    private func exclusionEditor(_ title: String, value: Binding<String>, items: Binding<[String]>) -> some View { Section(title) { ForEach(items.wrappedValue, id: \.self) { item in HStack { Text(item); Spacer(); Button { items.wrappedValue.removeAll { $0 == item } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("Remove \(item)") } }; HStack { TextField("Bundle identifier", text: value); Button("Add") { let trimmed = value.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines); if !trimmed.isEmpty && !items.wrappedValue.contains(trimmed) { items.wrappedValue.append(trimmed); value.wrappedValue = "" } } } } }
}

@MainActor public final class ClipboardSettingsModel: ObservableObject {
    @Published public var isEnabled = false
    @Published public var retainedCount = 0
    @Published public var encryptedBytes = 0
    @Published public var accessDescription = "Not checked"
    public var onEnableChanged: ((Bool) -> Void)?
    public var onRetentionChanged: ((Int, Int) -> Void)?
    public var onClear: (() -> Void)?
    public var onExclusionsChanged: ((Set<String>) -> Void)?
    public var onObserveExclusionsChanged: ((Set<String>) -> Void)?
    public init() {}
}

public struct DiagnosticsView: View {
    @EnvironmentObject private var store: ProductStore
    @State private var preview = ""; @State private var confirmAction: RecoveryAction?
    public init() {}
    public var body: some View { HSplitView { Form { Section("Environment") { row("Koru", store.diagnosticsSnapshot.appVersion); row("macOS", store.diagnosticsSnapshot.osVersion); row("Architecture", store.diagnosticsSnapshot.architecture) }; Section("Services") { health("Event tap", store.diagnosticsSnapshot.eventTap); health("Accessibility observer", store.diagnosticsSnapshot.accessibilityObserver); health("Pasteboard monitor", store.diagnosticsSnapshot.pasteboardMonitor); health("Repository", store.diagnosticsSnapshot.repository) }; Section("Recovery") { ForEach(RecoveryAction.allCases, id: \.self) { action in Button(label(action), role: destructive(action) ? .destructive : nil) { if destructive(action) { confirmAction = action } else { run(action) } } } } }.padding().frame(minWidth: 320); VStack(alignment: .leading) { HStack { Text("Support bundle preview").font(.headline); Spacer(); Button("Refresh") { makePreview() }; Button("Export…") { export() } }; TextEditor(text: $preview).font(.system(.caption, design: .monospaced)).accessibilityLabel("Redactable support bundle preview"); Text("Preview and remove anything you do not want to share. Koru never uploads this automatically.").font(.caption).foregroundStyle(.secondary) }.padding().frame(minWidth: 440) }.frame(minWidth: 780, minHeight: 520).onAppear(perform: makePreview).alert("Confirm recovery action", isPresented: Binding(get: { confirmAction != nil }, set: { if !$0 { confirmAction = nil } })) { Button("Cancel", role: .cancel) {}; Button("Continue", role: .destructive) { if let action = confirmAction { run(action) } } } message: { Text("This action can remove local data or replace the active vault. Continue only if you have reviewed the recovery guide.") } }
    private func row(_ label: String, _ value: String) -> some View { LabeledContent(label, value: value) }
    private func health(_ label: String, _ value: ServiceHealth) -> some View { HStack { Text(label); Spacer(); Image(systemName: value == .healthy ? "checkmark.circle.fill" : value == .degraded ? "exclamationmark.triangle.fill" : "pause.circle"); Text(value.rawValue.capitalized) }.accessibilityElement(children: .combine) }
    private func label(_ action: RecoveryAction) -> String { action.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
    private func destructive(_ action: RecoveryAction) -> Bool { [.clearClipboardHistory, .restoreEncryptedBackup, .resetVault].contains(action) }
    private func run(_ action: RecoveryAction) { Task { _ = await store.perform(action); makePreview() } }
    private func makePreview() { do { preview = String(decoding: try SupportBundle(snapshot: store.diagnosticsSnapshot, events: store.diagnosticEvents).data(), as: UTF8.self) } catch { preview = "Unable to create preview: \(error.localizedDescription)" } }
    private func export() { let panel = NSSavePanel(); panel.nameFieldStringValue = "Koru Support Bundle.json"; panel.allowedContentTypes = [.json]; panel.begin { response in guard response == .OK, let url = panel.url else { return }; try? Data(preview.utf8).write(to: url, options: .atomic) } }
}
