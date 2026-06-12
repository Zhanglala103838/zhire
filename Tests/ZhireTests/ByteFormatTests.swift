import XCTest
@testable import Zhire

final class ByteFormatTests: XCTestCase {
    func testGigabytes() {
        XCTAssertEqual(ByteFormat.memory(1_610_612_736), "1.5 GB")
    }
    func testMegabytes() {
        XCTAssertEqual(ByteFormat.memory(52_428_800), "50 MB")
    }
    func testZero() {
        // XCTest 运行环境下实测输出 "0 KB"（formatter 输出随运行环境变化，断言取实测值）
        XCTAssertEqual(ByteFormat.memory(0), "0 KB")
    }
    func testCPUTimeMinutes() {
        XCTAssertEqual(ByteFormat.cpuTime(90_000_000_000), "1.5 分钟")  // 90s
    }
    func testCPUTimeSeconds() {
        XCTAssertEqual(ByteFormat.cpuTime(3_200_000_000), "3.2 秒")
    }
    func testCPUTimeHours() {
        XCTAssertEqual(ByteFormat.cpuTime(7_200_000_000_000), "2.0 小时")
    }
}
