import XCTest
@testable import Zhire

final class ProcessSamplerLiveTests: XCTestCase {
    func testLiveSampleFindsOwnProcess() {
        let sampler = ProcessSampler()
        sampler.beginSession()
        let samples = sampler.sample()
        XCTAssertFalse(samples.isEmpty)
        // 必须能看到测试进程自己，且内存 > 0
        let me = samples.first { $0.pid == ProcessInfo.processInfo.processIdentifier }
        XCTAssertNotNil(me)
        XCTAssertGreaterThan(me?.memoryBytes ?? 0, 0)
    }

    func testSecondSampleProducesCPUPercent() {
        let sampler = ProcessSampler()
        sampler.beginSession()
        _ = sampler.sample()
        Thread.sleep(forTimeInterval: 0.2)
        let second = sampler.sample()
        let me = second.first { $0.pid == ProcessInfo.processInfo.processIdentifier }
        XCTAssertNotNil(me?.cpuPercent)  // 第二拍必须有差值
    }
}
