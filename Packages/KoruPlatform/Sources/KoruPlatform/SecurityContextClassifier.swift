import ApplicationServices
import Foundation
import KoruDomain

public enum ContextDecision: Equatable, Sendable { case allowed(CompatibilityCapability), blocked(String) }
public struct SecurityContext: Sendable {
    public var bundleIdentifier: String?; public var role: String?; public var subrole: String?; public var protectedContent: Bool?; public var editable: Bool?
    public init(bundleIdentifier: String?, role: String?, subrole: String?, protectedContent: Bool?, editable: Bool?) { self.bundleIdentifier = bundleIdentifier; self.role = role; self.subrole = subrole; self.protectedContent = protectedContent; self.editable = editable }
}
public struct SecurityContextClassifier: Sendable {
    public static let defaultExcludedBundleIDs: Set<String> = ["com.apple.keychainaccess", "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop", "com.lastpass.LastPass", "org.keepassxc.keepassxc"]
    private let excluded: Set<String>
    public init(excluded: Set<String> = defaultExcludedBundleIDs) { self.excluded = excluded }
    public func classify(_ context: SecurityContext) -> ContextDecision {
        guard let bundle = context.bundleIdentifier, !bundle.isEmpty else { return .blocked("unknown application") }
        guard !excluded.contains(bundle) else { return .blocked("excluded application") }
        guard context.protectedContent == false else { return .blocked("protected or unknown content") }
        guard context.subrole != kAXSecureTextFieldSubrole as String else { return .blocked("secure text field") }
        guard context.editable == true, let role = context.role, [kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String].contains(role) else { return .blocked("unsupported control") }
        return .allowed(.full)
    }
}
