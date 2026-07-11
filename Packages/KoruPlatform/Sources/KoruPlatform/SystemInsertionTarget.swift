import AppKit
import ApplicationServices
import CryptoKit
import Foundation
import KoruDomain

/// Re-fetches the focused AX element for every operation. No AX element or text is retained.
public final class SystemInsertionTarget: InsertionTargetAccessing, @unchecked Sendable {
    public init() {}

    public func currentSnapshot() -> TargetSnapshot? {
        guard let target = focused(), let range = range(target.element), let value = string(kAXValueAttribute, target.element) else { return nil }
        return TargetSnapshot(processIdentifier: target.pid, elementToken: target.token, replacementLocation: range.location, replacementLength: range.length, expectedValueDigest: Self.digest(value))
    }

    public func replace(range: NSRange, with text: String) -> Bool {
        guard let target = focused(), setRange(range, on: target.element) else { return false }
        return AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }

    public func select(range: NSRange) -> Bool {
        guard let target = focused() else { return false }
        return setRange(range, on: target.element)
    }

    public static func digest(_ value: String) -> Data { Data(SHA256.hash(data: Data(value.utf8))) }

    private func focused() -> (element: AXUIElement, pid: pid_t, token: String)? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide(); AXUIElementSetMessagingTimeout(system, 0.25)
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &raw) == .success, let raw else { return nil }
        let element = unsafeDowncast(raw, to: AXUIElement.self); var pid: pid_t = 0; AXUIElementGetPid(element, &pid)
        return (element, pid, "\(pid):\(CFHash(element))")
    }

    private func string(_ attribute: String, _ element: AXUIElement) -> String? { var raw: CFTypeRef?; return AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success ? raw as? String : nil }
    private func range(_ element: AXUIElement) -> CFRange? { var raw: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &raw) == .success, let value = raw as! AXValue?, AXValueGetType(value) == .cfRange else { return nil }; var range = CFRange(); return AXValueGetValue(value, .cfRange, &range) ? range : nil }
    private func setRange(_ range: NSRange, on element: AXUIElement) -> Bool { var value = CFRange(location: range.location, length: range.length); guard let ax = AXValueCreate(.cfRange, &value) else { return false }; return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, ax) == .success }
}
