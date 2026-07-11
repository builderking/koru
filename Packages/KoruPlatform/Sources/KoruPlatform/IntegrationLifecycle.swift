import AppKit
import Foundation

public protocol RuntimeIntegration: AnyObject { func start(); func stopAndPurge() }
public final class IntegrationLifecycle: @unchecked Sendable {
    public enum State: Equatable, Sendable { case active, paused, locked, sleeping, shuttingDown }
    private let integrations: [RuntimeIntegration]
    private let center: NotificationCenter
    private var tokens: [NSObjectProtocol] = []
    private var userPaused = false
    public var isUserPaused: Bool { userPaused }
    public private(set) var state: State = .active
    public init(integrations: [RuntimeIntegration], center: NotificationCenter = .default) { self.integrations = integrations; self.center = center }
    public func install() {
        tokens.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.transition(.locked) })
        tokens.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.transition(.sleeping) })
        tokens.append(center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.transition(self?.userPaused == true ? .paused : .active) })
        tokens.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.transition(self?.userPaused == true ? .paused : .active) })
    }
    public func togglePause() { userPaused.toggle(); transition(userPaused ? .paused : .active) }
    public func transition(_ next: State) { state = next; if next == .active { integrations.forEach { $0.start() } } else { integrations.forEach { $0.stopAndPurge() } } }
    deinit { tokens.forEach(center.removeObserver) }
}
