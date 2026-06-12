import Darwin

enum MachTime {
    /// 进程级缓存的真机 timebase
    static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// mach absolute time 单位 → 纳秒
    static func toNanoseconds(
        _ machTime: UInt64,
        timebase: mach_timebase_info_data_t = MachTime.timebase
    ) -> UInt64 {
        machTime * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    /// 当前时刻（ns），给差值计算当墙钟
    static func nowNanoseconds() -> UInt64 {
        toNanoseconds(mach_absolute_time())
    }
}
