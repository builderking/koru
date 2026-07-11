import AppKit
import Foundation
import KoruDomain

public enum PanelAnchor: Equatable, Sendable { case caret, fallback }
public struct PanelPlacement: Equatable, Sendable { public var origin: CGPoint; public var anchor: PanelAnchor }
public struct CaretPanelPlacer: Sendable {
    public init() {}
    public func place(panelSize: CGSize, caretAX: CGRect?, visibleFrame: CGRect) -> PanelPlacement {
        guard let caretAX, caretAX.width.isFinite, caretAX.height.isFinite, !caretAX.isNull else { return .init(origin: CGPoint(x: visibleFrame.midX - panelSize.width / 2, y: visibleFrame.midY - panelSize.height / 2), anchor: .fallback) }
        let caret = CGRect(x: caretAX.minX, y: visibleFrame.maxY - caretAX.maxY, width: caretAX.width, height: caretAX.height)
        var x = caret.minX; var y = caret.minY - panelSize.height - 6
        if y < visibleFrame.minY { y = caret.maxY + 6 }
        x = min(max(x, visibleFrame.minX), visibleFrame.maxX - panelSize.width); y = min(max(y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        return .init(origin: CGPoint(x: x, y: y), anchor: .caret)
    }
}

public final class KoruPanel: NSPanel {
    public init(contentRect: NSRect) { super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false); isFloatingPanel = true; level = .popUpMenu; collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; hidesOnDeactivate = false; isReleasedWhenClosed = false; backgroundColor = .clear; hasShadow = true }
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
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
