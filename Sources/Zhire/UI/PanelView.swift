import SwiftUI

struct PanelView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            systemOverview
            Divider()
            topSection(title: "CPU 占用 Top 5", samples: topCPU, metric: .cpu)
            Divider()
            topSection(title: "内存占用 Top 5", samples: topMemory, metric: .memory)
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            // 面板每次展开刷新自启状态（用户可能在系统设置里改过）
            launchAtLogin = LoginItem.isEnabled
            appState.beginProcessSampling()
            // 菜单栏面板标准卫生项：可加入所有 Space + 全屏辅助层，
            // 保证在全屏 Space 也能就地弹出。
            // 注：用户环境"全屏 Space 共存时点任何 app 菜单栏都闪屏"经取证为
            // macOS 26/27 系统级渲染行为（无 Space 切换事件、全 app 复现），非本 app 可修。
            DispatchQueue.main.async {
                for window in NSApp.windows where window.className.contains("MenuBarExtraWindow") {
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                }
            }
        }
        .onDisappear {
            appState.endProcessSampling()
        }
    }

    private var systemOverview: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(nsImage: ThermalColor.dotImage(for: appState.thermalState))
                Text("热压力：\(thermalLabel)")
                Spacer()
                Text(appState.snapshot?.cpuPercent.map { String(format: "CPU %.0f%%", $0) } ?? "CPU –")
                    .font(.system(.body).monospacedDigit())
            }
            if let snap = appState.snapshot {
                HStack {
                    Text("内存压力：\(snap.pressure.label)")
                        .foregroundStyle(snap.pressure == .normal ? Color.primary : Color.red)
                    Spacer()
                    Text("\(ByteFormat.memory(snap.memoryUsedBytes)) / \(ByteFormat.memory(snap.memoryTotalBytes))")
                        .font(.system(.body).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout)
    }

    private var thermalLabel: String {
        switch appState.thermalState {
        case .nominal: "正常"
        case .fair: "偏热"
        case .serious: "严重"
        case .critical: "临界"
        @unknown default: "未知"
        }
    }

    /// 实时 CPU% 排行；首帧（全员 cpuPercent==nil）退化为自启动累计排行
    private var topCPU: [ProcessSample] {
        let hasPercent = appState.processes.contains { $0.cpuPercent != nil }
        if hasPercent {
            return Array(appState.processes.sorted { ($0.cpuPercent ?? 0) > ($1.cpuPercent ?? 0) }.prefix(5))
        }
        return Array(appState.processes.sorted { $0.cpuTimeNanos > $1.cpuTimeNanos }.prefix(5))
    }

    private var topMemory: [ProcessSample] {
        Array(appState.processes.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(5))
    }

    private func topSection(title: String, samples: [ProcessSample], metric: ProcessRowView.Metric) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if samples.isEmpty {
                Text("采样中…").font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(samples) { s in
                ProcessRowView(sample: s, icon: appState.icon(pid: s.pid), metric: metric)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("详情窗口") {
                openWindow(id: "detail")
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Toggle("自启", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                // SMAppService 只在真 .app bundle 里可用，dev 裸跑禁用避免点击无效的困惑
                .disabled(Bundle.main.bundleIdentifier == nil)
                .onChange(of: launchAtLogin) { _, on in
                    if !LoginItem.setEnabled(on) { launchAtLogin = LoginItem.isEnabled }
                }
            Button("退出") { NSApp.terminate(nil) }
        }
        .controlSize(.small)
    }
}
