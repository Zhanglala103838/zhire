import XCTest
@testable import Zhire

final class RingBufferTests: XCTestCase {
    func testAppendBelowCapacity() {
        var buf = RingBuffer<Int>(capacity: 3)
        buf.append(1); buf.append(2)
        XCTAssertEqual(buf.elements, [1, 2])
    }
    func testOverwriteOldestAtCapacity() {
        var buf = RingBuffer<Int>(capacity: 3)
        for i in 1...5 { buf.append(i) }
        XCTAssertEqual(buf.elements, [3, 4, 5])  // 容量恒定，最旧的被覆盖
        XCTAssertEqual(buf.count, 3)
    }
    func testRemoveAll() {
        var buf = RingBuffer<Int>(capacity: 3)
        buf.append(1)
        buf.removeAll()
        XCTAssertEqual(buf.elements, [])
    }
}
