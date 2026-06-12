import AppKit
import Darwin

/// 进程显示名 / 图标 / 前后台判定。名字带缓存（进程名不会变）；
/// isBackground 不缓存（前台应用随时切换）。
///
/// 线程模型：`beginPass`/`resolve`/`prune` 仅在采样线程内调用（AppState 的
/// in-flight 护栏保证单飞）；`icon(pid:)` 仅主线程（UI 行渲染）调用，
/// 两侧各用各的缓存，互不共享可变状态。
final class ProcessDisplayResolver {
    private var nameCache: [pid_t: String] = [:]
    /// 本轮扫描的 GUI 应用查找表（每轮 beginPass 重建一次）。
    /// 此前每个 pid 单独 NSRunningApplication(processIdentifier:) 是 ~800 次
    /// LaunchServices 查询/2s，是窗口打开期 CPU 大头之一。
    private var appsByPID: [pid_t: NSRunningApplication] = [:]

    /// 图标缓存：仅主线程访问；GUI 应用量级 ~100，不随 daemon 增长，无需 prune
    private var iconCache: [pid_t: NSImage] = [:]

    /// 每轮扫描开始时调用一次：一次调用拿全量 GUI 应用建表
    func beginPass() {
        var map: [pid_t: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            map[app.processIdentifier] = app
        }
        appsByPID = map
    }

    /// 前台 = regular GUI 应用且正在交互（isActive）
    func resolve(pid: pid_t) -> (name: String, isBackground: Bool) {
        if let app = appsByPID[pid] {
            let isForeground = app.activationPolicy == .regular && app.isActive
            let name = nameCache[pid] ?? app.localizedName ?? Self.pathBasedName(pid)
            nameCache[pid] = name
            return (name, !isForeground)
        }
        // 非 GUI（daemon/helper）一律算后台
        let name = nameCache[pid] ?? Self.pathBasedName(pid)
        nameCache[pid] = name
        return (name, true)
    }

    /// 图标只给 GUI 进程；按 pid 缓存（图标不会变），仅主线程调用
    func icon(pid: pid_t) -> NSImage? {
        if let cached = iconCache[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return nil }
        iconCache[pid] = icon
        return icon
    }

    /// proc_pidpath 全路径取 basename，绕过 proc_name 16 字节截断
    private static func pathBasedName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        if proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 {
            let path = String(cString: buffer)
            if let base = path.split(separator: "/").last { return String(base) }
        }
        return "pid \(pid)"
    }

    func prune(alivePIDs: Set<pid_t>) {
        nameCache = nameCache.filter { alivePIDs.contains($0.key) }
    }
}
