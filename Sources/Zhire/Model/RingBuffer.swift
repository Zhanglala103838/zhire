/// 固定容量环形缓冲：满了覆盖最旧元素（历史曲线 30 分钟上限）
struct RingBuffer<Element> {
    private var storage: [Element] = []
    private var head = 0  // 下一个写入位置（仅在已满后有意义）
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    var count: Int { storage.count }

    /// 按时间序（最旧 → 最新）返回
    var elements: [Element] {
        guard storage.count == capacity else { return storage }
        return Array(storage[head...] + storage[..<head])
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        head = 0
    }
}
