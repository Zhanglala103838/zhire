import Darwin

/// 后台进程持续高 CPU 判定（连续 3 拍 >50% 标红）
struct SuspectDetector {
    let cpuThreshold: Double
    let requiredConsecutive: Int
    private var counters: [pid_t: Int] = [:]

    init(cpuThreshold: Double = 50.0, requiredConsecutive: Int = 3) {
        self.cpuThreshold = cpuThreshold
        self.requiredConsecutive = requiredConsecutive
    }

    /// 每个采样周期对每个进程调用一次；返回该进程当前是否可疑
    mutating func update(pid: pid_t, cpuPercent: Double?, isBackground: Bool) -> Bool {
        guard isBackground, let cpu = cpuPercent, cpu > cpuThreshold else {
            counters[pid] = 0
            return false
        }
        let streak = (counters[pid] ?? 0) + 1
        counters[pid] = streak
        return streak >= requiredConsecutive
    }

    mutating func prune(alivePIDs: Set<pid_t>) {
        counters = counters.filter { alivePIDs.contains($0.key) }
    }
}
