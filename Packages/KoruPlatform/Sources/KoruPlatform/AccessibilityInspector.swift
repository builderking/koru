import AppKit
import ApplicationServices
import KoruDomain
import OSLog

/// Resolves the focused UI element and records, without any field content, which accessor answered.
/// The system-wide `kAXFocusedUIElement` bridge returns cannotComplete for Chromium/Electron hosts
/// (Claude, VS Code, Slack, Chrome) even when the process is trusted; a query addressed directly to
/// the frontmost application's element answers once `AXManualAccessibility` has woken its tree.
public enum AXFocusResolver {
    public enum Path: String, Sendable { case systemWide = "focus.system_wide", appFallback = "focus.app_fallback", unresolved = "focus.unresolved" }
    static let log = Logger(subsystem: "dev.koru.app", category: "focus")
    private static let counters = FocusCounters()

    static func focusedElement(timeout: Float) -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        var raw: CFTypeRef?
        if AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &raw) == .success, let raw {
            record(.systemWide, bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
            return unsafeDowncast(raw, to: AXUIElement.self)
        }
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { record(.unresolved, bundleID: nil); return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var appRaw: CFTypeRef?
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &appRaw) == .success, let appRaw else {
            record(.unresolved, bundleID: bundleID); return nil
        }
        record(.appFallback, bundleID: bundleID)
        return unsafeDowncast(appRaw, to: AXUIElement.self)
    }

    private static func record(_ path: Path, bundleID: String?) {
        counters.increment(path, bundleID: bundleID)
        // The system-wide accessor answering is the quiet common case; only surface the Electron
        // fallback and outright failures so shipping logs stay clean but diagnosable.
        if path != .systemWide { log.notice("\(path.rawValue, privacy: .public) app=\(bundleID ?? "unknown", privacy: .public)") }
    }

    /// Per-application focus-path tallies keyed "focus.<path>|<bundle-id>" for the Diagnostics surface.
    public static func snapshotCounts() -> [String: Int] { counters.snapshot() }

    /// Latest resolved-element shape per bundle (role/editability/emptiness/caret — never field content).
    private static let shapes = FocusShapes()
    static func recordShape(bundleID: String?, role: String?, editable: Bool, emptyish: Bool, caret: Int?) {
        shapes.record(bundleID: bundleID ?? "unknown", value: "role=\(role ?? "nil") editable=\(editable) empty=\(emptyish) caret=\(caret.map(String.init) ?? "nil")")
    }
    public static func snapshotShapes() -> [String: String] { shapes.snapshot() }

}

final class FocusShapes: @unchecked Sendable {
    private let lock = NSLock(); private var map: [String: String] = [:]
    func record(bundleID: String, value: String) { lock.lock(); map[bundleID] = value; lock.unlock() }
    func snapshot() -> [String: String] { lock.lock(); defer { lock.unlock() }; return map }
}

private final class FocusCounters: @unchecked Sendable {
    private let lock = NSLock(); private var counts: [String: Int] = [:]
    func increment(_ path: AXFocusResolver.Path, bundleID: String?) { lock.lock(); counts["\(path.rawValue)|\(bundleID ?? "unknown")", default: 0] += 1; lock.unlock() }
    func snapshot() -> [String: Int] { lock.lock(); defer { lock.unlock() }; return counts }
}

public struct AXTargetSnapshot: Sendable {
    public var processIdentifier: pid_t
    public var role: String?
    public var subrole: String?
    public var isEditable: Bool
    public var isSecure: Bool
    public var valueLength: Int?
    public var selectedRange: CFRange?
    public var bounds: CGRect?
    public var value: String?
    public var elementToken: String
}

public protocol AccessibilityInspecting: Sendable {
    func focusedTarget() -> Result<AXTargetSnapshot, AXInspectionError>
}

public enum AXInspectionError: Error, Sendable { case permissionDenied, noFocusedElement, unsupported, cannotComplete(AXError) }

public final class SystemAccessibilityInspector: AccessibilityInspecting, @unchecked Sendable {
    private let timeout: Float
    public init(timeout: Float = 0.25) { self.timeout = timeout }

    public func focusedTarget() -> Result<AXTargetSnapshot, AXInspectionError> {
        guard AXIsProcessTrusted() else { return .failure(.permissionDenied) }
        guard let element = AXFocusResolver.focusedElement(timeout: timeout) else { return .failure(.noFocusedElement) }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let role = stringAttribute(kAXRoleAttribute, element)
        let subrole = stringAttribute(kAXSubroleAttribute, element)
        let secure = subrole == (kAXSecureTextFieldSubrole as String) || boolAttribute("AXProtectedContent", element) == true
        let value = stringAttribute(kAXValueAttribute, element)
        let range = rangeAttribute(kAXSelectedTextRangeAttribute, element)
        let editable = Self.editability(secure: secure, selectedTextSettable: isSettable(kAXSelectedTextAttribute, element))
        // Prefer the selection rectangle (the caret rectangle when the selection is empty), then the
        // caret at the selection end, then the character just before the caret — Chromium and Electron
        // hosts (Claude, Codex, VS Code) answer bounds-for-range for a collapsed selection with a
        // degenerate all-zero rect, and the preceding character is the closest honest anchor — then
        // the element frame, so apps that cannot answer bounds-for-range at all still get a usable
        // anchor instead of falling to screen center.
        let rangeBounds: CGRect?
        if let range {
            let caret = CFRange(location: range.location + range.length, length: 0)
            rangeBounds = Self.usableAnchor(bounds(for: range, element: element))
                ?? Self.usableAnchor(bounds(for: caret, element: element))
                ?? Self.usableAnchor(caret.location > 0 ? bounds(for: CFRange(location: caret.location - 1, length: 1), element: element) : nil)
                ?? rectAttribute("AXFrame", element)
        } else { rangeBounds = rectAttribute("AXFrame", element) }
        AXFocusResolver.recordShape(bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, role: role, editable: editable, emptyish: (value ?? "").allSatisfy(\.isNewline), caret: range?.location)
        return .success(.init(processIdentifier: pid, role: role, subrole: subrole, isEditable: editable, isSecure: secure, valueLength: value?.utf16.count, selectedRange: range, bounds: rangeBounds, value: value, elementToken: "\(pid):\(CFHash(element))"))
    }

    /// Chromium reports success for bounds-for-range on a collapsed selection while answering an
    /// all-zero rect; treating that as a real anchor pins the panel to a screen corner. A zero-width
    /// caret rectangle at a real position remains a valid anchor.
    static func usableAnchor(_ rect: CGRect?) -> CGRect? {
        guard let rect, rect.width.isFinite, rect.height.isFinite, !rect.isNull, rect != .zero else { return nil }
        return rect
    }

    /// Editability describes the AX element's write capability only. Secure status remains separate
    /// diagnostic metadata: recall may operate there when macOS delivers events, while capture and
    /// clipboard privacy policy continue to reject protected content independently.
    static func editability(secure _: Bool, selectedTextSettable: Bool) -> Bool { selectedTextSettable }

    private func stringAttribute(_ name: String, _ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func boolAttribute(_ name: String, _ element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    private func rectAttribute(_ name: String, _ element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let axValue = value as! AXValue?, AXValueGetType(axValue) == .cgRect else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(axValue, .cgRect, &rect) ? rect : nil
    }

    private func rangeAttribute(_ name: String, _ element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let axValue = value as! AXValue?, AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        return AXValueGetValue(axValue, .cfRange, &range) ? range : nil
    }

    private func bounds(for range: CFRange, element: AXUIElement) -> CGRect? {
        var mutableRange = range
        guard let parameter = AXValueCreate(.cfRange, &mutableRange) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &value) == .success,
              let axValue = value as! AXValue?, AXValueGetType(axValue) == .cgRect else { return nil }
        var rect = CGRect.zero
        return AXValueGetValue(axValue, .cgRect, &rect) ? rect : nil
    }

    private func isSettable(_ name: String, _ element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success && settable.boolValue
    }

    private func map(_ error: AXError, missing: AXInspectionError) -> AXInspectionError {
        error == .apiDisabled ? .permissionDenied : (error == .noValue ? missing : .cannotComplete(error))
    }
}

public enum AXObservedChange: Equatable, Sendable { case focusedElement, value, selection }
public final class AccessibilityObserverService: RuntimeIntegration, @unchecked Sendable {
    private var observer: AXObserver?; private var application: AXUIElement?; private let pid: pid_t; private let receive: @Sendable (AXObservedChange) -> Void
    public init(processIdentifier: pid_t, receive: @escaping @Sendable (AXObservedChange) -> Void) { pid = processIdentifier; self.receive = receive }
    public func start() {
        guard AXIsProcessTrusted(), observer == nil else { return }; let context = Unmanaged.passUnretained(self).toOpaque(); var created: AXObserver?
        guard AXObserverCreate(pid, { _, _, notification, context in guard let context else { return }; let service = Unmanaged<AccessibilityObserverService>.fromOpaque(context).takeUnretainedValue(); let name = notification as String; if name == kAXFocusedUIElementChangedNotification { service.receive(.focusedElement) } else if name == kAXValueChangedNotification { service.receive(.value) } else if name == kAXSelectedTextChangedNotification { service.receive(.selection) } }, &created) == .success, let created else { return }
        let app = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(app, 0.25)
        // Electron hosts build their accessibility tree lazily and never wake on their own; setting
        // AXManualAccessibility opts them in. Native apps report the attribute as unsupported — harmless.
        _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        [kAXFocusedUIElementChangedNotification, kAXValueChangedNotification, kAXSelectedTextChangedNotification].forEach { _ = AXObserverAddNotification(created, app, $0 as CFString, context) }
        observer = created; application = app; CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
    }
    public func stopAndPurge() { guard let observer else { application = nil; return }; CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes); self.observer = nil; application = nil }
}

public final class SystemSelectedTextReader: SelectedTextReading {
    public init() {}
    public func selectedText() -> Result<String, AXInspectionError> {
        guard AXIsProcessTrusted() else { return .failure(.permissionDenied) }; let system = AXUIElementCreateSystemWide(); AXUIElementSetMessagingTimeout(system, 0.25); var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success, let focused else { return .failure(.noFocusedElement) }
        let element = unsafeDowncast(focused, to: AXUIElement.self); var value: CFTypeRef?; let error = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard error == .success, let text = value as? String else { return .failure(error == .attributeUnsupported ? .unsupported : .cannotComplete(error)) }; return .success(text)
    }
}
