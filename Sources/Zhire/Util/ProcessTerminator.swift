import Darwin

/// 强退进程：第一次 SIGTERM（给清理机会），同一 pid 再次请求或发送失败 → SIGKILL
struct ProcessTerminator {
    private var terminated: Set<pid_t> = []

    @discardableResult
    mutating func terminate(pid: pid_t) -> Bool {
        if terminated.contains(pid) {
            return kill(pid, SIGKILL) == 0
        }
        terminated.insert(pid)
        if kill(pid, SIGTERM) != 0 {
            return kill(pid, SIGKILL) == 0
        }
        return true
    }
}
