import XCTest
@testable import Zhire

final class ProcessDeltaCalculatorTests: XCTestCase {
    func testFirstSampleHasNoPercent() {
        var calc = ProcessDeltaCalculator()
        XCTAssertNil(calc.cpuPercent(pid: 100, cpuTimeNanos: 1_000_000, timestampNanos: 0))
    }

    func testSecondSampleComputesPercent() {
        var calc = ProcessDeltaCalculator()
        _ = calc.cpuPercent(pid: 100, cpuTimeNanos: 0, timestampNanos: 0)
        // 2s 墙钟内烧了 1s CPU → 50%（单核口径）
        let pct = calc.cpuPercent(pid: 100, cpuTimeNanos: 1_000_000_000, timestampNanos: 2_000_000_000)
        XCTAssertEqual(pct, 50.0)
    }

    func testMultiCoreCanExceed100() {
        var calc = ProcessDeltaCalculator()
        _ = calc.cpuPercent(pid: 100, cpuTimeNanos: 0, timestampNanos: 0)
        let pct = calc.cpuPercent(pid: 100, cpuTimeNanos: 4_000_000_000, timestampNanos: 2_000_000_000)
        XCTAssertEqual(pct, 200.0)
    }

    func testPIDReuseNegativeDeltaTreatedAsZero() {
        // pid 复用 → 累计时间回退 → 按 0 处理
        var calc = ProcessDeltaCalculator()
        _ = calc.cpuPercent(pid: 100, cpuTimeNanos: 9_000_000_000, timestampNanos: 0)
        let pct = calc.cpuPercent(pid: 100, cpuTimeNanos: 1_000_000, timestampNanos: 2_000_000_000)
        XCTAssertEqual(pct, 0.0)
    }

    func testPruneDropsDeadPIDs() {
        var calc = ProcessDeltaCalculator()
        _ = calc.cpuPercent(pid: 100, cpuTimeNanos: 0, timestampNanos: 0)
        calc.prune(alivePIDs: [])  // 进程已死
        // 同 pid 再现（复用）应视为首拍
        XCTAssertNil(calc.cpuPercent(pid: 100, cpuTimeNanos: 0, timestampNanos: 1_000_000_000))
    }

    func testSinceSessionStartAccumulation() {
        // "窗口打开以来累计"：以首见时刻为基线
        var calc = ProcessDeltaCalculator()
        _ = calc.cpuPercent(pid: 100, cpuTimeNanos: 5_000_000_000, timestampNanos: 0)
        _ = calc.cpuPercent(pid: 100, cpuTimeNanos: 8_000_000_000, timestampNanos: 2_000_000_000)
        XCTAssertEqual(calc.cpuTimeSinceFirstSeen(pid: 100, currentCPUTimeNanos: 8_000_000_000), 3_000_000_000)
    }
}
