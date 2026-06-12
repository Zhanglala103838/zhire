import XCTest
@testable import Zhire

final class SuspectDetectorTests: XCTestCase {
    func testFlagsAfterThreeConsecutiveHighSamples() {
        var d = SuspectDetector()
        XCTAssertFalse(d.update(pid: 1, cpuPercent: 80, isBackground: true))
        XCTAssertFalse(d.update(pid: 1, cpuPercent: 80, isBackground: true))
        XCTAssertTrue(d.update(pid: 1, cpuPercent: 80, isBackground: true))
    }

    func testForegroundNeverFlagged() {
        var d = SuspectDetector()
        for _ in 0..<5 {
            XCTAssertFalse(d.update(pid: 1, cpuPercent: 99, isBackground: false))
        }
    }

    func testDipResetsCounter() {
        var d = SuspectDetector()
        _ = d.update(pid: 1, cpuPercent: 80, isBackground: true)
        _ = d.update(pid: 1, cpuPercent: 10, isBackground: true)  // 降下来 → 重置
        _ = d.update(pid: 1, cpuPercent: 80, isBackground: true)
        XCTAssertFalse(d.update(pid: 1, cpuPercent: 80, isBackground: true))  // 才第 2 拍
    }

    func testNilCPUDoesNotCount() {
        var d = SuspectDetector()
        XCTAssertFalse(d.update(pid: 1, cpuPercent: nil, isBackground: true))
    }

    func testExactly50DoesNotCount() {
        var d = SuspectDetector()
        for _ in 0..<4 {
            XCTAssertFalse(d.update(pid: 1, cpuPercent: 50, isBackground: true))  // >50 才算
        }
    }
}
