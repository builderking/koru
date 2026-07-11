import KoruDomain
import ServiceManagement

public protocol LoginItemControlling { var state: PermissionState { get }; func setEnabled(_ enabled: Bool) throws }
public final class LoginItemService: LoginItemControlling {
    public init() {}
    public var state: PermissionState { SystemPermissionChecker().loginItem() }
    public func setEnabled(_ enabled: Bool) throws { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
}
