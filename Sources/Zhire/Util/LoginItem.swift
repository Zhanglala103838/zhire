import Foundation
import ServiceManagement

/// 开机自启（一期实现，默认开启）。
/// 仅在真 .app bundle 里生效；`swift run` 裸跑会 throw，捕获后静默降级。
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("LoginItem toggle failed (dev 裸跑属预期): \(error)")
            return false
        }
    }

    /// 首启默认开启：仅当从未注册过时注册一次（不覆盖用户后来的手动关闭）
    static func registerOnFirstLaunch() {
        let key = "zhire.loginItem.attempted"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        setEnabled(true)
    }
}
