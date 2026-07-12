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
        guard let target = focused() else { return false }
        if canReplaceWholeValue(on: target.element) { return replaceWholeValue(range: range, with: text, on: target.element) }
        guard setRange(range, on: target.element) else { return false }
        return AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }

    public func select(range: NSRange) -> Bool {
        guard let target = focused() else { return false }
        return setRange(range, on: target.element)
    }

    public static func digest(_ value: String) -> Data { Data(SHA256.hash(data: Data(value.utf8))) }

    static func splicing(_ value: String, range: NSRange, replacement: String) -> (value: String, caret: NSRange)? {
        let source = value as NSString
        guard range.location != NSNotFound, range.location >= 0, range.length >= 0, NSMaxRange(range) <= source.length else { return nil }
        let updated = NSMutableString(string: value)
        updated.replaceCharacters(in: range, with: replacement)
        return (updated as String, NSRange(location: range.location + (replacement as NSString).length, length: 0))
    }

    private func focused() -> (element: AXUIElement, pid: pid_t, token: String)? {
        guard AXIsProcessTrusted() else { return nil }
        // Shares the inspector's resolver so the insertion target and the focus snapshot agree on the
        // same element (and token) even for Electron hosts reached through the app-level fallback.
        guard let element = AXFocusResolver.focusedElement(timeout: 0.25) else { return nil }
        var pid: pid_t = 0; AXUIElementGetPid(element, &pid)
        return (element, pid, "\(pid):\(CFHash(element))")
    }

    /// Plain single-line controls, including WebKit inputs, reliably support whole AXValue writes
    /// even when they falsely acknowledge AXSelectedText writes. Rich text areas are intentionally
    /// excluded so replacing a trigger cannot flatten surrounding attributes or markup.
    private func canReplaceWholeValue(on element: AXUIElement) -> Bool {
        guard string(kAXRoleAttribute, element) == (kAXTextFieldRole as String),
              string(kAXSubroleAttribute, element) != (kAXSecureTextFieldSubrole as String),
              bool("AXProtectedContent", element) != true else { return false }
        return true
    }

    private func replaceWholeValue(range replacementRange: NSRange, with text: String, on element: AXUIElement) -> Bool {
        guard let original = string(kAXValueAttribute, element),
              let originalSelection = range(element),
              let replacement = Self.splicing(original, range: replacementRange, replacement: text) else { return false }
        guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, replacement.value as CFTypeRef) == .success else { return false }
        let caretSet = setRange(replacement.caret, on: element)
        let valueMatches = string(kAXValueAttribute, element) == replacement.value
        let selectionMatches = range(element).map { NSRange(location: $0.location, length: $0.length) } == replacement.caret
        guard caretSet, valueMatches, selectionMatches else {
            _ = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, original as CFTypeRef)
            _ = setRange(NSRange(location: originalSelection.location, length: originalSelection.length), on: element)
            return false
        }
        return true
    }

    private func string(_ attribute: String, _ element: AXUIElement) -> String? { var raw: CFTypeRef?; return AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success ? raw as? String : nil }
    private func bool(_ attribute: String, _ element: AXUIElement) -> Bool? { var raw: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success else { return nil }; return raw as? Bool }
    private func range(_ element: AXUIElement) -> CFRange? { var raw: CFTypeRef?; guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &raw) == .success, let value = raw as! AXValue?, AXValueGetType(value) == .cfRange else { return nil }; var range = CFRange(); return AXValueGetValue(value, .cfRange, &range) ? range : nil }
    private func setRange(_ range: NSRange, on element: AXUIElement) -> Bool { var value = CFRange(location: range.location, length: range.length); guard let ax = AXValueCreate(.cfRange, &value) else { return false }; return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, ax) == .success }
}
