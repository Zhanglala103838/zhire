import Darwin

struct ProcessSample: Identifiable, Equatable {
    let pid: pid_t
    let name: String
    let isBackground: Bool
    let cpuTimeNanos: UInt64           // 自进程启动累计（首帧排行 + 抓历史凶手）
    let cpuTimeSinceOpenNanos: UInt64  // 本轮采样会话以来累计（诊断页主排序）
    let memoryBytes: UInt64            // ri_phys_footprint
    let cpuPercent: Double?            // 首拍 nil（差值无基线）
    let isSuspect: Bool

    var id: pid_t { pid }
}
