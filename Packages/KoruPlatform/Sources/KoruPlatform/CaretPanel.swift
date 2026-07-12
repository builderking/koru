import AppKit
import Foundation
import KoruDomain
import SwiftUI

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
        return value.unicodeScalars.allSatisfy { !$0.properties.isWhitespace && !CharacterSet.controlCharacters.contains($0) } ? .character(value) : .reset
    }
}

/// The recall panel can never become key during typed sessions, so every click arrives as a
/// "first mouse" — the hosting view must accept it or rows are not selectable at all.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

public struct RecallResult: Identifiable, Equatable, Sendable { public var id: String; public var title: String; public var preview: String; public init(id: String, title: String, preview: String) { self.id = id; self.title = title; self.preview = preview } }
public struct ResultNavigator: Sendable {
    public private(set) var results: [RecallResult] = []; public private(set) var selectedID: String?
    public init() {}
    public mutating func update(_ updated: [RecallResult]) { let old = selectedID; results = updated; selectedID = old.flatMap { id in updated.contains { $0.id == id } ? id : nil } ?? updated.first?.id }
    public mutating func move(_ delta: Int) { guard !results.isEmpty else { selectedID = nil; return }; let index = selectedID.flatMap { id in results.firstIndex { $0.id == id } } ?? 0; selectedID = results[(index + delta + results.count) % results.count].id }
    public mutating func dismiss() { selectedID = nil }
    public var selected: RecallResult? { selectedID.flatMap { id in results.first { $0.id == id } } }
}
