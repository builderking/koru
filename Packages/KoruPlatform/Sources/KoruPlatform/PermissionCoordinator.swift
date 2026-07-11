import ApplicationServices
import CoreGraphics
import Foundation
import KoruDomain
import ServiceManagement

public protocol PermissionChecking: Sendable {
    func accessibility(prompt: Bool) -> Bool
    func inputListening(request: Bool) -> Bool
    func eventPosting(request: Bool) -> Bool
    func pasteboard() -> PermissionState
    func loginItem() -> PermissionState
}

public struct SystemPermissionChecker: PermissionChecking {
    public init() {}
    public func accessibility(prompt: Bool) -> Bool {
        if prompt { return AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) }
        return AXIsProcessTrusted()
    }
    public func inputListening(request: Bool) -> Bool { request ? CGRequestListenEventAccess() : CGPreflightListenEventAccess() }
    public func eventPosting(request: Bool) -> Bool { request ? CGRequestPostEventAccess() : CGPreflightPostEventAccess() }
    public func pasteboard() -> PermissionState { .unavailable } // AccessBehavior is guarded in the clipboard integration on newer SDKs.
    public func loginItem() -> PermissionState {
        switch SMAppService.mainApp.status {
        case .enabled: .granted
        case .notRegistered: .denied
        case .requiresApproval: .denied
        case .notFound: .unavailable
        @unknown default: .unknown
        }
    }
}

public final class PermissionCoordinator: @unchecked Sendable {
    public typealias Observer = @Sendable (PermissionSnapshot) -> Void
    private let checker: PermissionChecking
    private let lock = NSLock()
    private var observers: [UUID: Observer] = [:]
    private var previous: PermissionSnapshot?
    public private(set) var snapshot: PermissionSnapshot

    public init(checker: PermissionChecking = SystemPermissionChecker()) {
        self.checker = checker
        snapshot = .init(accessibility: .unknown, inputListening: .unknown, eventPosting: .unknown, pasteboard: .unknown, loginItem: .unknown, hotKeys: [:])
    }
    @discardableResult public func observe(_ observer: @escaping Observer) -> UUID { let id = UUID(); lock.withLock { observers[id] = observer }; observer(snapshot); return id }
    public func removeObserver(_ id: UUID) { lock.withLock { observers.removeValue(forKey: id) } }
    public func setHotKeyState(_ state: HotKeyState, command: String) { lock.withLock { snapshot.hotKeys[command] = state }; publish() }
    @discardableResult public func refresh() -> PermissionSnapshot {
        let old = lock.withLock { snapshot }
        let next = PermissionSnapshot(
            accessibility: transition(old.accessibility, checker.accessibility(prompt: false)),
            inputListening: transition(old.inputListening, checker.inputListening(request: false)),
            eventPosting: transition(old.eventPosting, checker.eventPosting(request: false)),
            pasteboard: checker.pasteboard(), loginItem: checker.loginItem(), hotKeys: old.hotKeys)
        lock.withLock { previous = snapshot; snapshot = next }
        publish(); return next
    }
    public func requestAccessibility() { _ = checker.accessibility(prompt: true); _ = refresh() }
    public func requestInputListening() { _ = checker.inputListening(request: true); _ = refresh() }
    public func requestEventPosting() { _ = checker.eventPosting(request: true); _ = refresh() }
    private func transition(_ old: PermissionState, _ granted: Bool) -> PermissionState { granted ? .granted : (old == .granted ? .revoked : .denied) }
    private func publish() { let pair = lock.withLock { (snapshot, Array(observers.values)) }; pair.1.forEach { $0(pair.0) } }
}

private extension NSLock { func withLock<T>(_ body: () -> T) -> T { lock(); defer { unlock() }; return body() } }
