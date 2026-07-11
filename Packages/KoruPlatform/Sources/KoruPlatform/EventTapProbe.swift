import CoreGraphics
import Foundation

public enum EventTapHealth: Sendable, Equatable { case stopped, running, unavailable, disabledByTimeout, disabledByUserInput }

public final class EventTapProbe: @unchecked Sendable {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let queue = DispatchQueue(label: "dev.koru.harness.event-tap")
    public private(set) var health: EventTapHealth = .stopped
    public private(set) var eventCount = 0

    public init() {}

    public func start() {
        queue.async { [self] in
            guard tap == nil else { return }
            let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
            let context = Unmanaged.passUnretained(self).toOpaque()
            guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let probe = Unmanaged<EventTapProbe>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout { probe.health = .disabledByTimeout; CGEvent.tapEnable(tap: probe.tap!, enable: true) }
                else if type == .tapDisabledByUserInput { probe.health = .disabledByUserInput }
                else { probe.eventCount += 1 }
                return Unmanaged.passUnretained(event)
            }, userInfo: context) else { health = .unavailable; return }
            tap = created
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: created, enable: true)
            health = .running
            CFRunLoopRun()
        }
    }

    public func stop() {
        guard let tap else { health = .stopped; return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopSourceInvalidate(source) }
        CFMachPortInvalidate(tap)
        self.tap = nil; source = nil; health = .stopped
    }
}
