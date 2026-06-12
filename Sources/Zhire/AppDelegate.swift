import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 单实例守护：终止同 bundle id 的旧实例（新实例存活）
        if let bundleID = Bundle.main.bundleIdentifier {
            let myPID = ProcessInfo.processInfo.processIdentifier
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            where app.processIdentifier != myPID {
                app.forceTerminate()
            }
        }
        NSApp.setActivationPolicy(.accessory)
        LoginItem.registerOnFirstLaunch()
    }
}
