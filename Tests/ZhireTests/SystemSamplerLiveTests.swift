import XCTest
@testable import Zhire

final class SystemSamplerLiveTests: XCTestCase {
    func testLiveTicksAndMemory() {
        let ticks = SystemSampler.readCPUTicks()
        XCTAssertNotNil(ticks)
        XCTAssertGreaterThan(ticks!.busy + ticks!.idle, 0)

        // host_statistics64 在系统高负载下极罕见地单次失败（兜底返回 used=0），
        // 生产路径下一拍自愈；测试重试一次消除假阳性
        var (used, total) = SystemSampler.readMemory()
        if used == 0 { (used, total) = SystemSampler.readMemory() }
        XCTAssertGreaterThan(total, 0)
        XCTAssertGreaterThan(used, 0)
        XCTAssertLessThan(used, total)
    }

    func testRapidResampleReusesCPUPercentInsteadOfGarbage() {
        // 间隔 <1s 的重复采样：毫秒级 tick 窗口会算出 80%+ 鬼值，
        // 必须复用上一拍 CPU% 而不是重新计算
        let sampler = SystemSampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 1.1)
        let valid = sampler.sample()
        XCTAssertNotNil(valid.cpuPercent)
        Thread.sleep(forTimeInterval: 0.05)
        let rapid = sampler.sample()
        XCTAssertEqual(rapid.cpuPercent, valid.cpuPercent)  // 完全相同（复用），而非重新算
    }

    func testSecondSampleHasCPUPercent() {
        let sampler = SystemSampler()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 1.1)  // 须超过 minimumCPUSampleGapNanos 才出新 CPU%
        let second = sampler.sample()
        XCTAssertNotNil(second.cpuPercent)
        XCTAssertGreaterThanOrEqual(second.cpuPercent!, 0)
        XCTAssertLessThanOrEqual(second.cpuPercent!, 100)
    }
}
