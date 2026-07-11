import Carbon
import Foundation
import KoruDomain

public enum HotKeyCommand: UInt32, CaseIterable, Sendable { case openKoru = 1, openClipboard, saveSelection }
public struct HotKeyBinding: Hashable, Sendable { public var keyCode: UInt32; public var modifiers: UInt32; public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers } }
public protocol GlobalHotKeyRegistering: AnyObject { func register(_ command: HotKeyCommand, binding: HotKeyBinding) -> HotKeyState; func unregisterAll() }

public final class CarbonHotKeyRegistrar: GlobalHotKeyRegistering {
    private var references: [HotKeyCommand: EventHotKeyRef] = [:]
    public init() {}
    public func register(_ command: HotKeyCommand, binding: HotKeyBinding) -> HotKeyState {
        if references[command] != nil { return .registered }
        var reference: EventHotKeyRef?
        let signature = OSType(0x4B4F5255) // KORU
        let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, EventHotKeyID(signature: signature, id: command.rawValue), GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return status == eventHotKeyExistsErr ? .conflict : .failed }
        references[command] = reference
        return .registered
    }
    public func unregisterAll() { references.values.forEach { _ = UnregisterEventHotKey($0) }; references.removeAll() }
    deinit { unregisterAll() }
}
