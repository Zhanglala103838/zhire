import XCTest
@testable import Zhire

final class MachTimeTests: XCTestCase {
    func testAppleSiliconTimebase() {
        // Apple Silicon: numer=125, denom=3 → 3 个 mach 单位 = 125ns
        let tb = mach_timebase_info_data_t(numer: 125, denom: 3)
        XCTAssertEqual(MachTime.toNanoseconds(3, timebase: tb), 125)
        XCTAssertEqual(MachTime.toNanoseconds(6, timebase: tb), 250)
    }

    func testIntelTimebaseIdentity() {
        let tb = mach_timebase_info_data_t(numer: 1, denom: 1)
        XCTAssertEqual(MachTime.toNanoseconds(123_456_789, timebase: tb), 123_456_789)
    }

    func testZero() {
        let tb = mach_timebase_info_data_t(numer: 125, denom: 3)
        XCTAssertEqual(MachTime.toNanoseconds(0, timebase: tb), 0)
    }

    func testRealTimebaseIsLoaded() {
        // 真机 timebase 的 numer/denom 不为 0
        XCTAssertGreaterThan(MachTime.timebase.numer, 0)
        XCTAssertGreaterThan(MachTime.timebase.denom, 0)
    }
}
