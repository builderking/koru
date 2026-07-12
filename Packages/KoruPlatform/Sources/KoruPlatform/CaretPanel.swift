import AppKit
import Foundation
import KoruDomain
import SwiftUI

enum RecallPanelPalette {
    static func accent(forDarkMode dark: Bool) -> NSColor {
        let components: (CGFloat, CGFloat, CGFloat) = dark ? (0x55, 0xCF, 0x9C) : (0x0C, 0x7A, 0x50)
        return NSColor(srgbRed: components.0 / 255, green: components.1 / 255, blue: components.2 / 255, alpha: 1)
    }

    static let adaptiveAccent = NSColor(name: nil) { appearance in
        accent(forDarkMode: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
    }
}

public enum PanelAnchor: Equatable, Sendable { case caret, fallback }
public struct PanelPlacement: Equatable, Sendable { public var origin: CGPoint; public var anchor: PanelAnchor }
public struct CaretPanelPlacer: Sendable {
    public init() {}
    /// AX geometry is global with a top-left origin on the primary display; AppKit is bottom-left.
    /// The flip must use the primary display height — other screens' frames are unrelated to the origin.
    public static func appKitRect(fromAX rect: CGRect?, primaryScreenHeight: CGFloat) -> CGRect? {
        guard let rect, rect.width.isFinite, rect.height.isFinite, !rect.isNull else { return nil }
        return CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
    public func place(panelSize: CGSize, caret: CGRect?, visibleFrame: CGRect) -> PanelPlacement {
        guard let caret, caret.width.isFinite, caret.height.isFinite, !caret.isNull else { return .init(origin: CGPoint(x: visibleFrame.midX - panelSize.width / 2, y: visibleFrame.midY - panelSize.height / 2), anchor: .fallback) }
        var x = caret.minX; var y = caret.minY - panelSize.height - 6
        if y < visibleFrame.minY { y = caret.maxY + 6 }
        x = min(max(x, visibleFrame.minX), visibleFrame.maxX - panelSize.width); y = min(max(y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        return .init(origin: CGPoint(x: x, y: y), anchor: .caret)
    }
}

public final class KoruPanel: NSPanel {
    /// Typed sessions leave the destination app's field focused; manual sessions without an insertion
    /// target take keyboard focus themselves so navigation works even when the event tap cannot run.
    public var allowsKeyboardFocus = false
    var onPanelCommand: ((TypedInputMessage) -> Bool)?
    public init(contentRect: NSRect) { super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false); isFloatingPanel = true; level = .popUpMenu; collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; hidesOnDeactivate = false; isReleasedWhenClosed = false; backgroundColor = .clear; hasShadow = true }
    public override var canBecomeKey: Bool { allowsKeyboardFocus }
    public override var canBecomeMain: Bool { false }
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let onPanelCommand, let message = Self.message(event), onPanelCommand(message) { return }
        super.sendEvent(event)
    }

    /// Mirrors TypedEventTapService.message for keys delivered straight to the key panel.
    static func message(_ event: NSEvent) -> TypedInputMessage? {
        switch event.keyCode { case 53: return .dismiss; case 36: return .confirm; case 48: return .tabTransfer; case 51: return .backspace; case 125: return .navigation(1); case 126: return .navigation(-1); case 123, 124, 115, 119, 116, 121: return .reset; default: break }
        guard event.modifierFlags.intersection([.command, .control]).isEmpty else { return .reset }
        guard let value = event.characters, !value.isEmpty, value.utf16.count <= 4 else { return nil }
        return value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } ? .character(value) : .reset
    }
}

/// The recall panel can never become key during typed sessions, so every click arrives as a
/// "first mouse" — the hosting view must accept it or rows are not selectable at all.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

public struct RecallResult: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var preview: String
    public var contentType: ContentType
    public var thumbnailData: Data?

    public init(id: String, title: String, preview: String, contentType: ContentType = .plainText, thumbnailData: Data? = nil) {
        self.id = id
        self.title = title
        self.preview = preview
        self.contentType = contentType
        self.thumbnailData = thumbnailData
    }

    public var displayText: String {
        let value = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? title : value
    }
}

public struct RecallPanelLayout: Equatable, Sendable {
    public static let width: CGFloat = 344
    public static let maximumHeight: CGFloat = 260
    public static let minimumHeight: CGFloat = 42
    public static let horizontalInset: CGFloat = 7
    public static let verticalInset: CGFloat = 7
    public static let rowSpacing: CGFloat = 3
    public static let clipboardHeaderHeight: CGFloat = 27

    public init() {}

    public func rowHeight(for row: RecallResult) -> CGFloat {
        if row.contentType == .image { return 58 }
        return estimatedLineCount(for: row.displayText) == 1 ? 31 : 43
    }

    public func contentHeight(rows: [RecallResult], showsClipboardHeader: Bool, notice: String?) -> CGFloat {
        let rowsHeight: CGFloat
        if rows.isEmpty {
            rowsHeight = 40
        } else {
            rowsHeight = rows.reduce(0) { $0 + rowHeight(for: $1) }
                + CGFloat(max(0, rows.count - 1)) * Self.rowSpacing
        }
        let header = showsClipboardHeader ? Self.clipboardHeaderHeight : 0
        let noticeHeight: CGFloat = notice == nil ? 0 : 42
        return Self.verticalInset * 2 + header + rowsHeight + noticeHeight
    }

    public func panelHeight(rows: [RecallResult], showsClipboardHeader: Bool, notice: String?) -> CGFloat {
        min(Self.maximumHeight, max(Self.minimumHeight, contentHeight(rows: rows, showsClipboardHeader: showsClipboardHeader, notice: notice)))
    }

    private func estimatedLineCount(for value: String) -> Int {
        let lines = value.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        return lines.count > 1 || value.count > 54 ? 2 : 1
    }
}

public struct RecallPanelContentView: View {
    let source: String
    let query: String
    let rows: [RecallResult]
    let selectedID: String?
    let notice: String?
    let select: (String) -> Void

    public init(source: String, query: String, rows: [RecallResult], selectedID: String?, notice: String?, select: @escaping (String) -> Void) {
        self.source = source
        self.query = query
        self.rows = rows
        self.selectedID = selectedID
        self.notice = notice
        self.select = select
    }

    private let layout = RecallPanelLayout()
    private var showsClipboardHeader: Bool { source == "Clipboard" }
    private var height: CGFloat { layout.panelHeight(rows: rows, showsClipboardHeader: showsClipboardHeader, notice: notice) }
    private var accent: Color { Color(nsColor: RecallPanelPalette.adaptiveAccent) }

    public var body: some View {
        VStack(spacing: 0) {
            if showsClipboardHeader { clipboardHeader }
            if rows.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: RecallPanelLayout.rowSpacing) {
                            ForEach(rows) { row in rowButton(row).id(row.id) }
                        }
                    }
                    .onChange(of: selectedID) { selected in
                        guard let selected else { return }
                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(selected, anchor: .center) }
                    }
                }
            }
            if let notice { noticeView(notice) }
        }
        .padding(.horizontal, RecallPanelLayout.horizontalInset)
        .padding(.vertical, RecallPanelLayout.verticalInset)
        .frame(width: RecallPanelLayout.width, height: height)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.84))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.black.opacity(0.1), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
    }

    private var clipboardHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "clipboard").font(.system(size: 10, weight: .semibold))
            Text("Clipboard").font(.system(size: 11, weight: .semibold))
            Spacer(minLength: 8)
            if !query.isEmpty, query != KoruPolicy.reservedClipboardCommand {
                Text(query).font(.system(size: 10, design: .monospaced)).lineLimit(1).foregroundStyle(Color.black.opacity(0.48))
            }
        }
        .foregroundStyle(Color.black.opacity(0.72))
        .padding(.horizontal, 5)
        .frame(height: RecallPanelLayout.clipboardHeaderHeight)
        .overlay(alignment: .bottom) { Divider().opacity(0.45) }
    }

    private var emptyState: some View {
        Text(showsClipboardHeader ? "Clipboard history is empty" : "No saved matches")
            .font(.system(size: 11))
            .foregroundStyle(Color.black.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func rowButton(_ row: RecallResult) -> some View {
        Button { select(row.id) } label: {
            HStack(spacing: 8) {
                if row.contentType == .image { thumbnail(row.thumbnailData) }
                rowText(row)
                Spacer(minLength: 6)
                if row.id == selectedID {
                    Image(systemName: "return")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: layout.rowHeight(for: row), maxHeight: layout.rowHeight(for: row), alignment: .leading)
            .contentShape(Rectangle())
            .background(row.id == selectedID ? accent.opacity(0.14) : Color.black.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.title), \(row.displayText)")
    }

    @ViewBuilder private func rowText(_ row: RecallResult) -> some View {
        if row.contentType == .image {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                if !row.preview.isEmpty {
                    Text(row.preview).font(.system(size: 10.5)).foregroundStyle(Color.black.opacity(0.5)).lineLimit(1)
                }
            }
            .foregroundStyle(Color.black.opacity(0.82))
        } else {
            Text(row.displayText)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.black.opacity(0.82))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder private func thumbnail(_ data: Data?) -> some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.1), lineWidth: 0.5) }
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.06))
                .frame(width: 46, height: 46)
                .overlay { Image(systemName: "photo").font(.system(size: 14)).foregroundStyle(Color.black.opacity(0.35)) }
        }
    }

    private func noticeView(_ notice: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundStyle(.orange)
            Text(notice).font(.system(size: 9.5)).foregroundStyle(Color.black.opacity(0.58)).lineLimit(2)
        }
        .padding(.horizontal, 5)
        .padding(.top, 5)
        .frame(height: 42, alignment: .top)
    }
}

public struct ResultNavigator: Sendable {
    public private(set) var results: [RecallResult] = []; public private(set) var selectedID: String?
    public init() {}
    public mutating func update(_ updated: [RecallResult]) { let old = selectedID; results = updated; selectedID = old.flatMap { id in updated.contains { $0.id == id } ? id : nil } ?? updated.first?.id }
    public mutating func move(_ delta: Int) { guard !results.isEmpty else { selectedID = nil; return }; let index = selectedID.flatMap { id in results.firstIndex { $0.id == id } } ?? 0; selectedID = results[(index + delta + results.count) % results.count].id }
    public mutating func dismiss() { selectedID = nil }
    public var selected: RecallResult? { selectedID.flatMap { id in results.first { $0.id == id } } }
}
