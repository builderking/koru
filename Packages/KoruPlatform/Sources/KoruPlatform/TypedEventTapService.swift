import CoreGraphics
import Foundation

public enum TypedInputMessage: Equatable, Sendable { case character(String), backspace, navigation(Int), confirm, dismiss, reset, pointerDown, tabTransfer }
public final class TypedEventTapService: RuntimeIntegration, @unchecked Sendable {
    /// Synthetic replacement events carry this marker so the event tap never treats Koru's own
    /// Backspace and Command-V sequence as fresh user input.
    static let syntheticEventMarker: Int64 = 0x4B4F5255
    private var tap: CFMachPort?; private var source: CFRunLoopSource?; private let queue = DispatchQueue(label: "dev.builderking.koru.typed-event-tap")
    private let permission: @Sendable () -> Bool
    private let enabled: @Sendable () -> Bool
    private let receive: @Sendable (TypedInputMessage) -> Bool
    private let observedEvents = TypedEventCounter()
    public private(set) var health: EventTapHealth = .stopped
    public var observedEventCount: Int { observedEvents.value }
    public init(permission: @escaping @Sendable () -> Bool = { CGPreflightListenEventAccess() }, enabled: @escaping @Sendable () -> Bool = { true }, receive: @escaping @Sendable (TypedInputMessage) -> Bool) { self.permission = permission; self.enabled = enabled; self.receive = receive }
    public func start() {
        guard tap == nil else { return }
        guard enabled() else { health = .stopped; return }
        guard permission() else { health = .unavailable; return }
        queue.async { [weak self] in self?.run() }
    }
    private func run() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.leftMouseDown.rawValue) | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: koruTypedEventCallback, userInfo: context) else { health = .unavailable; return }
        tap = port; source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0); CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes); health = .running; CFRunLoopRun()
    }
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker { return false }
        if type == .keyDown || type == .leftMouseDown || type == .rightMouseDown { observedEvents.increment() }
        if type == .tapDisabledByTimeout { health = .disabledByTimeout; if permission(), let tap { CGEvent.tapEnable(tap: tap, enable: true) } }
        else if type == .tapDisabledByUserInput { health = .disabledByUserInput }
        else if type == .leftMouseDown || type == .rightMouseDown { _ = receive(.pointerDown) }
        else if let message = Self.message(event) { return receive(message) }
        return false
    }
    static func message(_ event: CGEvent) -> TypedInputMessage? {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        switch code { case 53: return .dismiss; case 36: return .confirm; case 48: return .tabTransfer; case 51: return .backspace; case 125: return .navigation(1); case 126: return .navigation(-1); case 123, 124, 115, 119, 116, 121: return .reset; default: break }
        guard event.flags.intersection([.maskCommand, .maskControl]).isEmpty else { return .reset }
        var length = 0; event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil); guard length > 0 && length <= 4 else { return nil }
        var chars = [UniChar](repeating: 0, count: length); event.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &chars)
        // Spaces are ordinary trigger characters so a saved text may use a multi-word tag. Return
        // and Tab are classified above; other control characters still reset the rolling suffix.
        let value = String(utf16CodeUnits: chars, count: length)
        return value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } ? .character(value) : .reset
    }
    public func stopAndPurge() { if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }; if let source { CFRunLoopSourceInvalidate(source) }; tap = nil; source = nil; health = .stopped }
}

private final class TypedEventCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); count += 1; lock.unlock() }
}

private func koruTypedEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, context: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let context else { return Unmanaged.passUnretained(event) }
    return Unmanaged<TypedEventTapService>.fromOpaque(context).takeUnretainedValue().handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
}
