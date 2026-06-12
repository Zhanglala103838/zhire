import Foundation

enum MemoryPressureLevel: Int {
    case normal = 1, warning = 2, critical = 4

    var label: String {
        switch self {
        case .normal: "正常"
        case .warning: "警告"
        case .critical: "危急"
        }
    }
}

struct SystemSnapshot {
    let cpuPercent: Double?            // 首拍无基线为 nil
    let memoryUsedBytes: UInt64        // active+wired+compressed 近似口径
    let memoryTotalBytes: UInt64
    let pressure: MemoryPressureLevel
    let timestamp: Date
}
