import Darwin

/// 每进程 CPU 时间差值计算（纯逻辑，syscall 无关，可单测）。
/// 输入均为换算后的纳秒。
struct ProcessDeltaCalculator {
    private struct Record {
        let cpuTimeNanos: UInt64
        let timestampNanos: UInt64
        let baselineCPUTimeNanos: UInt64  // 首见时的累计值，算"会话以来"用
    }
    private var records: [pid_t: Record] = [:]

    /// 返回单核口径 CPU%（可 >100）；首拍返回 nil；pid 复用（差值为负）返回 0
    mutating func cpuPercent(pid: pid_t, cpuTimeNanos: UInt64, timestampNanos: UInt64) -> Double? {
        defer {
            let baseline = records[pid]?.baselineCPUTimeNanos ?? cpuTimeNanos
            // 复用 pid 累计值回退 → 重置基线
            let safeBaseline = cpuTimeNanos < baseline ? cpuTimeNanos : baseline
            records[pid] = Record(
                cpuTimeNanos: cpuTimeNanos,
                timestampNanos: timestampNanos,
                baselineCPUTimeNanos: safeBaseline
            )
        }
        guard let prev = records[pid] else { return nil }
        guard cpuTimeNanos >= prev.cpuTimeNanos, timestampNanos > prev.timestampNanos else {
            return 0.0  // pid 复用 / 时钟异常防御
        }
        let cpuDelta = Double(cpuTimeNanos - prev.cpuTimeNanos)
        let wallDelta = Double(timestampNanos - prev.timestampNanos)
        return cpuDelta / wallDelta * 100.0
    }

    /// "采样会话开始以来"累计 CPU 时间（诊断页排序用）
    func cpuTimeSinceFirstSeen(pid: pid_t, currentCPUTimeNanos: UInt64) -> UInt64 {
        guard let rec = records[pid], currentCPUTimeNanos >= rec.baselineCPUTimeNanos else { return 0 }
        return currentCPUTimeNanos - rec.baselineCPUTimeNanos
    }

    /// 剔除已死进程，防 pid 复用串数据 + 防字典无限涨
    mutating func prune(alivePIDs: Set<pid_t>) {
        records = records.filter { alivePIDs.contains($0.key) }
    }

    mutating func reset() { records.removeAll() }
}
