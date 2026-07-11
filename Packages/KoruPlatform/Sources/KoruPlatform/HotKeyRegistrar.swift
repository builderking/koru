import Carbon
import Foundation
import KoruDomain

public enum HotKeyCommand: UInt32, CaseIterable, Sendable { case openKoru = 1, openClipboard, saveSelection, pauseResume }
public struct HotKeyBinding: Hashable, Sendable { public var keyCode: UInt32; public var modifiers: UInt32; public init(keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers } }
public final class HotKeyConfigurationStore {
    private let defaults: UserDefaults; public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func binding(for command: HotKeyCommand, fallback: HotKeyBinding) -> HotKeyBinding { let key = "hotkey.\(command.rawValue)"; guard let pair = defaults.array(forKey: key) as? [Int], pair.count == 2 else { return fallback }; return .init(keyCode: UInt32(pair[0]), modifiers: UInt32(pair[1])) }
    public func save(_ binding: HotKeyBinding, for command: HotKeyCommand) { defaults.set([Int(binding.keyCode), Int(binding.modifiers)], forKey: "hotkey.\(command.rawValue)") }
}
public protocol GlobalHotKeyRegistering: AnyObject {
    var states: [HotKeyCommand: HotKeyState] { get }
    func register(_ command: HotKeyCommand, binding: HotKeyBinding) -> HotKeyState
    func rebind(_ command: HotKeyCommand, to binding: HotKeyBinding) -> HotKeyState
    func unregister(_ command: HotKeyCommand)
    func unregisterAll()
}

public final class CarbonHotKeyRegistrar: GlobalHotKeyRegistering {
    private static let signature = OSType(0x4B4F5255)
    private var references: [HotKeyCommand: EventHotKeyRef] = [:]
    private var bindings: [HotKeyCommand: HotKeyBinding] = [:]
    private var handler: EventHandlerRef?
    private let onCommand: (HotKeyCommand) -> Void
    public private(set) var states: [HotKeyCommand: HotKeyState] = [:]
    public init(onCommand: @escaping (HotKeyCommand) -> Void = { _ in }) {
        self.onCommand = onCommand
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID(); guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout.size(ofValue: id), nil, &id) == noErr,
                  id.signature == CarbonHotKeyRegistrar.signature, let command = HotKeyCommand(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(context).takeUnretainedValue().onCommand(command); return noErr
        }, 1, &event, context, &handler)
    }
    public func register(_ command: HotKeyCommand, binding: HotKeyBinding) -> HotKeyState {
        guard valid(binding) else { states[command] = .reservedOrUnsupported; return .reservedOrUnsupported }
        guard !bindings.contains(where: { $0.key != command && $0.value == binding }) else { states[command] = .conflict; return .conflict }
        if references[command] != nil { return states[command] ?? .registered }
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(binding.keyCode, binding.modifiers, EventHotKeyID(signature: Self.signature, id: command.rawValue), GetApplicationEventTarget(), 0, &reference)
        let state: HotKeyState = status == noErr && reference != nil ? .registered : (status == eventHotKeyExistsErr ? .conflict : .failed)
        if let reference, state == .registered { references[command] = reference; bindings[command] = binding }
        states[command] = state; return state
    }
    public func rebind(_ command: HotKeyCommand, to binding: HotKeyBinding) -> HotKeyState {
        let old = bindings[command]; unregister(command)
        let state = register(command, binding: binding)
        if state != .registered, let old { _ = register(command, binding: old) }
        return state
    }
    public func unregister(_ command: HotKeyCommand) { if let ref = references.removeValue(forKey: command) { _ = UnregisterEventHotKey(ref) }; bindings.removeValue(forKey: command); states[command] = .disabled }
    public func unregisterAll() { HotKeyCommand.allCases.forEach(unregister) }
    private func valid(_ binding: HotKeyBinding) -> Bool {
        let required = UInt32(cmdKey | controlKey); return binding.keyCode < 128 && binding.modifiers & required != 0 && binding.keyCode != UInt32(kVK_Escape)
    }
    deinit { unregisterAll(); if let handler { RemoveEventHandler(handler) } }
}
