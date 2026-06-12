import Foundation

/// 热压力监听：事件驱动零轮询
final class ThermalMonitor {
    private var observer: NSObjectProtocol?

    var onChange: ((ProcessInfo.ThermalState) -> Void)?

    var current: ProcessInfo.ThermalState { ProcessInfo.processInfo.thermalState }

    func start() {
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.onChange?(self.current)
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
