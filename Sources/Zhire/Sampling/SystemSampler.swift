import Darwin
import Foundation

/// 系统级采样：每次 sample() 是 3 个轻量 syscall（host_processor_info /
/// host_statistics64 / sysctl），无任何后台线程。
final class SystemSampler {
    /// CPU% 最小采样间隔：低于此间隔的重采样复用上一拍结果。
    /// 毫秒级 tick 窗口会算出 80%+ 的鬼值（实测 12ms 窗口出 77.8%）。
    static let minimumCPUSampleGapNanos: UInt64 = 1_000_000_000

    private var previousTicks: CPUTicks?
    private var lastTickSampleNanos: UInt64?
    private var lastCPUPercent: Double?

    func sample() -> SystemSnapshot {
        let now = MachTime.nowNanoseconds()
        let (used, total) = Self.readMemory()
        let pressure = Self.readPressureLevel()

        // 间隔过短：不动 tick 基线，CPU% 复用上一拍
        if let last = lastTickSampleNanos, now &- last < Self.minimumCPUSampleGapNanos {
            return SystemSnapshot(
                cpuPercent: lastCPUPercent,
                memoryUsedBytes: used,
                memoryTotalBytes: total,
                pressure: pressure,
                timestamp: Date()
            )
        }

        let ticks = Self.readCPUTicks()
        var cpuPercent: Double?
        if let prev = previousTicks, let curr = ticks {
            cpuPercent = CPUTicks.systemPercent(previous: prev, current: curr)
        }
        if let curr = ticks {
            previousTicks = curr
            lastTickSampleNanos = now
        }
        if let pct = cpuPercent { lastCPUPercent = pct }

        return SystemSnapshot(
            cpuPercent: cpuPercent,
            memoryUsedBytes: used,
            memoryTotalBytes: total,
            pressure: pressure,
            timestamp: Date()
        )
    }

    /// host_processor_info 全核 tick 求和。
    /// ⚠️ 返回数组必须 vm_deallocate，否则 10s 轮询下稳定泄漏。
    static func readCPUTicks() -> CPUTicks? {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &cpuCount, &infoArray, &infoCount
        )
        guard kr == KERN_SUCCESS, let info = infoArray else { return nil }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: info)),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }
        var busy: UInt64 = 0, idle: UInt64 = 0
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * Int(CPU_STATE_MAX)
            // tick 计数是 32 位无符号，先按位转 UInt32 再升位，避免负数
            busy += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
                  + UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
                  + UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            idle  += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
        }
        return CPUTicks(busy: busy, idle: idle)
    }

    /// 物理内存总量恒定，进程生命周期内只查一次
    static let totalMemoryBytes: UInt64 = {
        var total: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &size, nil, 0)
        return total
    }()

    /// 物理内存：used = active + wired + compressed（近似口径）
    static func readMemory() -> (used: UInt64, total: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = totalMemoryBytes
        guard kr == KERN_SUCCESS else { return (0, total) }
        let page = UInt64(vm_kernel_page_size)
        let used = (UInt64(stats.active_count)
                  + UInt64(stats.wire_count)
                  + UInt64(stats.compressor_page_count)) * page
        return (used, total)
    }

    /// 系统内存压力档位（系统自己的判定）
    static func readPressureLevel() -> MemoryPressureLevel {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0)
        return MemoryPressureLevel(rawValue: Int(level)) ?? .normal
    }
}
