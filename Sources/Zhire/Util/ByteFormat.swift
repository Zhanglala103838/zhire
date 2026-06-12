import Foundation

/// ByteCountFormatter 非线程安全：本类型仅限主线程（UI 层）调用
enum ByteFormat {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory  // 活动监视器同款 1024 进制
        return f
    }()

    static func memory(_ bytes: UInt64) -> String {
        formatter.string(fromByteCount: Int64(bytes))
    }

    /// 累计 CPU 时间的人类可读格式（诊断页/首帧排行用）
    static func cpuTime(_ nanos: UInt64) -> String {
        let seconds = Double(nanos) / 1_000_000_000
        if seconds < 60 { return String(format: "%.1f 秒", seconds) }
        if seconds < 3600 { return String(format: "%.1f 分钟", seconds / 60) }
        return String(format: "%.1f 小时", seconds / 3600)
    }
}
