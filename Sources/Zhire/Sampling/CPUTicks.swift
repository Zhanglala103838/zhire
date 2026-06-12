struct CPUTicks: Equatable {
    let busy: UInt64   // user + system + nice 全核求和
    let idle: UInt64

    /// 系统 CPU 占用 0~100；无差值或计数回退返回 nil
    static func systemPercent(previous: CPUTicks, current: CPUTicks) -> Double? {
        guard current.busy >= previous.busy, current.idle >= previous.idle else { return nil }
        let busyDelta = Double(current.busy - previous.busy)
        let idleDelta = Double(current.idle - previous.idle)
        let total = busyDelta + idleDelta
        guard total > 0 else { return nil }
        return busyDelta / total * 100.0
    }
}
