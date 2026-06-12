import XCTest
@testable import Zhire

final class CPUTicksTests: XCTestCase {
    func testFiftyPercent() {
        let prev = CPUTicks(busy: 1000, idle: 1000)
        let curr = CPUTicks(busy: 1100, idle: 1100)
        XCTAssertEqual(CPUTicks.systemPercent(previous: prev, current: curr), 50.0)
    }
    func testFullLoad() {
        let prev = CPUTicks(busy: 0, idle: 0)
        let curr = CPUTicks(busy: 200, idle: 0)
        XCTAssertEqual(CPUTicks.systemPercent(previous: prev, current: curr), 100.0)
    }
    func testNoDeltaReturnsNil() {
        let t = CPUTicks(busy: 100, idle: 100)
        XCTAssertNil(CPUTicks.systemPercent(previous: t, current: t))
    }
    func testCounterRegressionReturnsNil() {
        // 计数器回绕/异常：current < previous → nil 而非负数
        let prev = CPUTicks(busy: 1000, idle: 1000)
        let curr = CPUTicks(busy: 900, idle: 1100)
        XCTAssertNil(CPUTicks.systemPercent(previous: prev, current: curr))
    }
}
