import AppKit
import Combine
import SwiftUI

struct HistoryPoint: Identifiable {
    let timestamp: Date
    let cpuPercent: Double
    let memoryUsedFraction: Double  // used/total 0~1
    let pressure: MemoryPressureLevel
    var id: Date { timestamp }
}

@MainActor
final class AppState: ObservableObject {
    // ── 发布给 UI 的状态 ──
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var snapshot: SystemSnapshot?
    @Published var processes: [ProcessSample] = []
    @Published var historyPoints: [HistoryPoint] = []
    /// 菜单栏专用：取整后才发布，数值不变不触发重绘
    @Published var menuCPUPercent: Int?
    /// 菜单栏内存占用百分比（used/total），同样变了才发布
    @Published var menuMemoryPercent: Int?

    // ── 采样器 ──
    private let systemSampler = SystemSampler()
    private let processSampler = ProcessSampler()
    private let thermalMonitor = ThermalMonitor()
    /// 30 分钟 @ 2s = 900 点
    private var history = RingBuffer<HistoryPoint>(capacity: 900)

    // ── 生命周期 ──
    private var systemTimer: Timer?
    private var processTimer: Timer?
    /// 面板与窗口各自 +1/-1；>0 时进程扫描开
    private var processDemand = 0
    /// 进程扫描在飞标记（MainActor 上读写，天然串行）
    private var sampleInFlight = false
    /// 窗口可见时才记历史
    private(set) var windowVisible = false
    private var asleep = false

    static let idleInterval: TimeInterval = 10   // 平时系统级采样间隔
    static let activeInterval: TimeInterval = 2  // 面板/窗口打开时间隔

    /// 全局单例：App body 用普通 let 持有它（不订阅发布），
    /// 否则任何 @Published 变化都会重算 MenuBarExtra scene → status item 被拆建 →
    /// 菜单栏抖动 + 呈现中的面板被收掉（实测）
    static let shared = AppState()

    init() {
        thermalState = thermalMonitor.current
        thermalMonitor.onChange = { [weak self] state in self?.thermalState = state }
        thermalMonitor.start()
        observeSleepWake()
        startSystemTimer(interval: Self.idleInterval, fireNow: true)
    }

    // ── 系统级采样（常驻）──
    /// fireNow 仅 app 启动时为 true。面板开/关引起的 interval 切换严禁同步首拍：
    /// 同步发布会让 MenuBarExtra label 在 popover 呈现动画中重建，AppKit 会竞态性
    /// 收掉呈现中的面板（实测 onAppear 后 12ms 触发 onDisappear）。
    private func startSystemTimer(interval: TimeInterval, fireNow: Bool = false) {
        systemTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.systemTick() }
        }
        timer.tolerance = interval * 0.2  // ≥20% tolerance 让系统合并唤醒
        RunLoop.main.add(timer, forMode: .common)
        systemTimer = timer
        if fireNow {
            systemTick()
        } else {
            // 延迟到呈现动画结束后再出首拍
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.systemTick()
            }
        }
    }

    private func systemTick() {
        guard !asleep else { return }
        let snap = systemSampler.sample()
        snapshot = snap
        // 菜单栏数字：变了才发布
        let rounded = snap.cpuPercent.map { Int($0.rounded()) }
        if rounded != menuCPUPercent { menuCPUPercent = rounded }
        let memRounded: Int? = snap.memoryTotalBytes > 0
            ? Int((Double(snap.memoryUsedBytes) / Double(snap.memoryTotalBytes) * 100).rounded())
            : nil
        if memRounded != menuMemoryPercent { menuMemoryPercent = memRounded }
        // 历史：仅窗口可见期间记录
        if windowVisible, let cpu = snap.cpuPercent, snap.memoryTotalBytes > 0 {
            history.append(HistoryPoint(
                timestamp: snap.timestamp,
                cpuPercent: cpu,
                memoryUsedFraction: Double(snap.memoryUsedBytes) / Double(snap.memoryTotalBytes),
                pressure: snap.pressure
            ))
            historyPoints = history.elements
        }
    }

    // ── 进程级采样（按需）──
    func beginProcessSampling() {
        processDemand += 1
        guard processDemand == 1 else { return }
        processSampler.beginSession()
        startSystemTimer(interval: Self.activeInterval)  // 打开期间系统采样也提到 2s
        let timer = Timer(timeInterval: Self.activeInterval, repeats: true) { [weak self] _ in
            self?.processTick()
        }
        timer.tolerance = 0.4
        RunLoop.main.add(timer, forMode: .common)
        processTimer = timer
        processTick()  // 立即出首屏（自启动累计排行）
    }

    func endProcessSampling() {
        processDemand = max(0, processDemand - 1)
        guard processDemand == 0 else { return }
        processTimer?.invalidate()
        processTimer = nil
        processes = []
        startSystemTimer(interval: Self.idleInterval)  // 回到低频
    }

    /// 扫描在后台队列跑，不挡主线程；in-flight 护栏防止上一轮未归时并发扫描
    nonisolated private func processTick() {
        Task { @MainActor [weak self] in
            guard let self, !self.asleep, !self.sampleInFlight else { return }
            self.sampleInFlight = true
            defer { self.sampleInFlight = false }
            let sampler = self.processSampler
            let samples = await Task.detached(priority: .utility) { sampler.sample() }.value
            guard self.processDemand > 0 else { return }   // 停采后不回填 stale 数据
            self.processes = samples
        }
    }

    // ── 窗口可见性（历史记录开关）──
    func windowDidAppear() {
        windowVisible = true
        history.removeAll()
        historyPoints = []
        beginProcessSampling()
    }

    func windowDidDisappear() {
        windowVisible = false
        endProcessSampling()
    }

    // ── 睡眠/锁屏：采样全停 ──
    private func observeSleepWake() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.asleep = true }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.asleep = false }
        }
        nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.asleep = true }
        }
        nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.asleep = false }
        }
    }

    func icon(pid: pid_t) -> NSImage? { processSampler.icon(pid: pid) }
}
