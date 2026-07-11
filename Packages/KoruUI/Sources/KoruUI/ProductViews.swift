import KoruDomain
import SwiftUI

public struct LibraryView: View {
    public init() {}
    public var body: some View { NavigationSplitView { List { Label("Saved", systemImage: "bookmark"); Label("Clipboard", systemImage: "clipboard"); Label("Archive", systemImage: "archivebox"); Label("Recently Deleted", systemImage: "trash") }.navigationTitle("Koru") } detail: { VStack(spacing: KoruSpacing.standard) { Image(systemName: "text.quote").font(.largeTitle); Text("No saved item selected").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity) } }
}
public struct SettingsView: View { public init() {} ; public var body: some View { Form { Section("General") { Text("Koru runs locally. Clipboard history and typed matching start off.") }; Section("Privacy") { Text("No account, background network request, or automatic insertion.") } }.padding().frame(width: 480, height: 300) } }
public struct OnboardingView: View { public init() {} ; public var body: some View { VStack(spacing: KoruSpacing.section) { Image(systemName: "text.bubble").font(.system(size: 40)); Text("Koru remembers your writing where you write.").font(.title2); Text("Start in Hotkey-only mode. Enable typed matching or Clipboard separately when you are ready.").foregroundStyle(.secondary) }.multilineTextAlignment(.center).padding(32).frame(width: 520, height: 320) } }
public struct DiagnosticsView: View { public init() {} ; public var body: some View { Form { LabeledContent("Network", value: "No background requests"); LabeledContent("Clipboard history", value: "Off by default"); LabeledContent("Automatic insertion", value: "Never") }.padding().frame(width: 480, height: 260) } }
