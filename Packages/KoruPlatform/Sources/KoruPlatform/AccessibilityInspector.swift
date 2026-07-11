import AppKit
import ApplicationServices
import KoruDomain

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
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, timeout)
        var rawFocused: CFTypeRef?
        let focusError = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &rawFocused)
        guard focusError == .success, let rawFocused else { return .failure(map(focusError, missing: .noFocusedElement)) }
        let element = unsafeDowncast(rawFocused, to: AXUIElement.self)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let role = stringAttribute(kAXRoleAttribute, element)
        let subrole = stringAttribute(kAXSubroleAttribute, element)
        let secure = subrole == (kAXSecureTextFieldSubrole as String) || boolAttribute("AXProtectedContent", element) == true
        let value = stringAttribute(kAXValueAttribute, element)
        let range = rangeAttribute(kAXSelectedTextRangeAttribute, element)
        let editableRoles = [kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String]
        let editable = !secure && editableRoles.contains(role ?? "") && isSettable(kAXSelectedTextAttribute, element)
        let rangeBounds: CGRect?
        if let range { rangeBounds = bounds(for: range, element: element) } else { rangeBounds = nil }
        return .success(.init(processIdentifier: pid, role: role, subrole: subrole, isEditable: editable, isSecure: secure, valueLength: value?.utf16.count, selectedRange: range, bounds: rangeBounds, value: value, elementToken: "\(pid):\(CFHash(element))"))
    }

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
