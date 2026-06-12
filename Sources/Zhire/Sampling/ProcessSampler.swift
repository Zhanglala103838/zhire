import AppKit
import Darwin
import Foundation

/// 全量进程扫描。仅面板/窗口可见时由 AppState 周期调用。
/// 非 @MainActor：扫描跑在后台队列，结果回主线程发布。
final class ProcessSampler {
    /// 单轮扫描进程数硬上限（异常暴涨时不阻塞 UI）
    static let maxProcessCount = 4096

    private var delta = ProcessDeltaCalculator()
    private var suspect = SuspectDetector()
    private let resolver = ProcessDisplayResolver()

    /// 新一轮采样会话（面板/窗口重新打开时调用，重置"会话以来"基线）
    func beginSession() {
        delta.reset()
        suspect = SuspectDetector()
    }

    func sample() -> [ProcessSample] {
        resolver.beginPass()  // 一次性建 GUI 应用查找表，替代每 pid 一次 LS 查询
        let pids = Self.listAllPIDs()
        let now = MachTime.nowNanoseconds()
        var samples: [ProcessSample] = []
        samples.reserveCapacity(pids.count)
        var alive = Set<pid_t>()

        for pid in pids.prefix(Self.maxProcessCount) where pid > 0 {
            guard let usage = Self.rusage(for: pid) else { continue }  // 已退出/无权限 → 静默跳过
            alive.insert(pid)

            // ⚠️ ri_*_time 是 mach absolute time，必须换算
            let cpuTime = MachTime.toNanoseconds(usage.ri_user_time)
                        + MachTime.toNanoseconds(usage.ri_system_time)
            let memory = usage.ri_phys_footprint

            let pct = delta.cpuPercent(pid: pid, cpuTimeNanos: cpuTime, timestampNanos: now)
            let (name, isBackground) = resolver.resolve(pid: pid)
            let isSuspect = suspect.update(pid: pid, cpuPercent: pct, isBackground: isBackground)

            samples.append(ProcessSample(
                pid: pid,
                name: name,
                isBackground: isBackground,
                cpuTimeNanos: cpuTime,
                cpuTimeSinceOpenNanos: delta.cpuTimeSinceFirstSeen(pid: pid, currentCPUTimeNanos: cpuTime),
                memoryBytes: memory,
                cpuPercent: pct,
                isSuspect: isSuspect
            ))
        }

        delta.prune(alivePIDs: alive)
        suspect.prune(alivePIDs: alive)
        resolver.prune(alivePIDs: alive)
        return samples
    }

    func icon(pid: pid_t) -> NSImage? { resolver.icon(pid: pid) }

    static func listAllPIDs() -> [pid_t] {
        let expected = proc_listallpids(nil, 0)
        guard expected > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(expected) + 64)  // 留余量
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard filled > 0 else { return [] }
        return Array(pids.prefix(Int(filled)))
    }

    static func rusage(for pid: pid_t) -> rusage_info_current? {
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
            }
        }
        guard result == 0 else { return nil }
        return info
    }
}
