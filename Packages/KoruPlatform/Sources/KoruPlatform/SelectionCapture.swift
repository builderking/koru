import AppKit
import ApplicationServices
import Foundation
import KoruDomain

public struct SelectionEvidence: Equatable, Sendable { public var selectedRange: NSRange?; public var valueUTF16Length: Int?; public var bounds: CGRect?; public var contextAllowed: Bool; public var notificationsSupported: Bool; public init(selectedRange: NSRange?, valueUTF16Length: Int?, bounds: CGRect?, contextAllowed: Bool, notificationsSupported: Bool) { self.selectedRange = selectedRange; self.valueUTF16Length = valueUTF16Length; self.bounds = bounds; self.contextAllowed = contextAllowed; self.notificationsSupported = notificationsSupported } }
public struct SelectionIconPolicy: Sendable {
    public init() {}
    public func shouldShow(_ evidence: SelectionEvidence) -> Bool { guard evidence.contextAllowed, evidence.notificationsSupported, let range = evidence.selectedRange, let count = evidence.valueUTF16Length, let bounds = evidence.bounds else { return false }; return range.location == 0 && range.length == count && count > 0 && !bounds.isNull && bounds.width > 0 && bounds.height > 0 }
}
@MainActor public final class SelectionIconController {
    public let panel: KoruPanel; private let action: () -> Void
    public init(action: @escaping () -> Void) { self.action = action; panel = KoruPanel(contentRect: .init(x: 0, y: 0, width: 28, height: 28)); let button = NSButton(image: NSImage(systemSymbolName: "bookmark", accessibilityDescription: "Save selected text to Koru")!, target: nil, action: nil); button.toolTip = "Save selected text to Koru"; button.bezelStyle = .circular; panel.contentView = button; button.target = self; button.action = #selector(activate) }
    public func show(at origin: CGPoint) { panel.setFrameOrigin(origin); panel.orderFrontRegardless() }
    public func dismiss() { panel.orderOut(nil) }
    @objc private func activate() { dismiss(); action() }
}

public enum SelectionIconPlacement {
    /// Floats the icon just above the trailing corner of the selection. Selection bounds arrive in AX
    /// top-left-origin coordinates; the returned origin is AppKit bottom-left global space.
    public static func origin(selectionAX: CGRect, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: selectionAX.maxX + 6, y: primaryScreenHeight - selectionAX.minY + 4)
    }
}

/// Watches the frontmost application's focused element and shows the optional save icon when the
/// entire content of a nonsecure editable field is selected (the product's selection affordance).
@MainActor public final class SelectionAffordanceMonitor: @preconcurrency RuntimeIntegration {
    private let inspector: AccessibilityInspecting
    private let permission: @Sendable () -> Bool
    private let policy = SelectionIconPolicy()
    private let classifier = SecurityContextClassifier()
    private let icon: SelectionIconController
    private var observer: AccessibilityObserverService?
    private var workspaceToken: NSObjectProtocol?
    private var debounce: Timer?
    private var enabled = true
    var notificationsSupportedForTesting: Bool?

    public init(inspector: AccessibilityInspecting = SystemAccessibilityInspector(), permission: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() }, action: @escaping () -> Void) {
        self.inspector = inspector; self.permission = permission; icon = SelectionIconController(action: action)
    }

    public func setEnabled(_ value: Bool) { enabled = value; if !value { icon.dismiss() } }

    public func start() {
        guard workspaceToken == nil else { return }
        workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated { self?.follow(pid) }
        }
        follow(NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }

    public func stopAndPurge() {
        if let workspaceToken { NSWorkspace.shared.notificationCenter.removeObserver(workspaceToken) }
        workspaceToken = nil; observer?.stopAndPurge(); observer = nil; debounce?.invalidate(); debounce = nil; icon.dismiss()
    }

    private func follow(_ pid: pid_t?) {
        icon.dismiss(); observer?.stopAndPurge(); observer = nil
        guard let pid, pid != ProcessInfo.processInfo.processIdentifier, permission() else { return }
        let service = AccessibilityObserverService(processIdentifier: pid) { [weak self] _ in
            DispatchQueue.main.async { self?.scheduleEvaluation() }
        }
        service.start(); observer = service
    }

    private func scheduleEvaluation() {
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.evaluate() } }
    }

    func evaluate() {
        guard enabled, permission(), case let .success(snapshot) = inspector.focusedTarget() else { icon.dismiss(); return }
        let bundleID = NSRunningApplication(processIdentifier: snapshot.processIdentifier)?.bundleIdentifier
        let decision = classifier.classify(.init(bundleIdentifier: bundleID, role: snapshot.role, subrole: snapshot.subrole, protectedContent: snapshot.isSecure, editable: snapshot.isEditable))
        let allowed: Bool = if case .allowed = decision { true } else { false }
        let evidence = SelectionEvidence(
            selectedRange: snapshot.selectedRange.map { NSRange(location: $0.location, length: $0.length) },
            valueUTF16Length: snapshot.valueLength,
            bounds: snapshot.bounds,
            contextAllowed: allowed,
            notificationsSupported: notificationsSupportedForTesting ?? (observer != nil))
        guard policy.shouldShow(evidence), let bounds = snapshot.bounds else { icon.dismiss(); return }
        icon.show(at: SelectionIconPlacement.origin(selectionAX: bounds, primaryScreenHeight: NSScreen.screens.first?.frame.maxY ?? 0))
    }

    var iconIsVisibleForTesting: Bool { icon.panel.isVisible }
}

public struct SaveConfirmationInput: Equatable, Sendable { public enum Source: Equatable, Sendable { case service, accessibilityShortcut, selectionIcon }; public var plainText: String; public var richText: Data?; public var source: Source }
@MainActor public protocol SaveConfirmationReceiving: AnyObject { func receive(_ input: SaveConfirmationInput) }
@MainActor public final class SelectionServiceProcessor {
    private weak var receiver: SaveConfirmationReceiving?
    public init(receiver: SaveConfirmationReceiving) { self.receiver = receiver }
    public func process(_ pasteboard: NSPasteboard) -> String? {
        let text = pasteboard.string(forType: .string); let rich = pasteboard.data(forType: .rtf)
        guard let text, !text.isEmpty else { return "Koru received no supported text." }
        receiver?.receive(.init(plainText: text, richText: rich, source: .service)); return nil
    }
}

public protocol SelectedTextReading { func selectedText() -> Result<String, AXInspectionError> }
public enum SaveSelectionShortcutOutcome: Equatable { case opened, useService, blocked }
@MainActor public struct SaveSelectionShortcut {
    private let reader: SelectedTextReading; private weak var receiver: SaveConfirmationReceiving?
    public init(reader: SelectedTextReading, receiver: SaveConfirmationReceiving) { self.reader = reader; self.receiver = receiver }
    public func invoke(context: ContextDecision) -> SaveSelectionShortcutOutcome {
        guard case .allowed = context else { return .blocked }
        guard case let .success(text) = reader.selectedText(), !text.isEmpty else { return .useService }
        receiver?.receive(.init(plainText: text, richText: nil, source: .accessibilityShortcut)); return .opened
    }
}
