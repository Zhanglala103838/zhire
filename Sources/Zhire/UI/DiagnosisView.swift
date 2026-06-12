import SwiftUI

struct DiagnosisView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            list
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Image(nsImage: ThermalColor.dotImage(for: appState.thermalState))
            Text("热压力：\(label(appState.thermalState))").font(.headline)
            Spacer()
            Text("按 CPU 时间消耗排行——烧得越多的进程越靠前")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func label(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal: "正常"
        case .fair: "偏热"
        case .serious: "严重"
        case .critical: "临界"
        @unknown default: "未知"
        }
    }

    /// 主排序：会话以来累计；会话刚开始全为 0 时退化为自启动累计
    private var ranked: [ProcessSample] {
        let sessionMeaningful = appState.processes.contains { $0.cpuTimeSinceOpenNanos > 0 }
        if sessionMeaningful {
            return appState.processes.sorted { $0.cpuTimeSinceOpenNanos > $1.cpuTimeSinceOpenNanos }
        }
        return appState.processes.sorted { $0.cpuTimeNanos > $1.cpuTimeNanos }
    }

    private var list: some View {
        List(Array(ranked.prefix(30))) { s in
            HStack(spacing: 8) {
                if let icon = appState.icon(pid: s.pid) {
                    Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                } else {
                    Image(systemName: "gearshape").frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(s.name)
                        if s.isSuspect {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red).font(.caption)
                        }
                    }
                    Text(s.isBackground ? "后台" : "前台")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("本窗口期 \(ByteFormat.cpuTime(s.cpuTimeSinceOpenNanos))")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(s.isSuspect ? Color.red : Color.primary)
                    HStack(spacing: 8) {
                        Text(s.cpuPercent.map { String(format: "现在 %.1f%%", $0) } ?? "现在 –")
                        Text("自启动 \(ByteFormat.cpuTime(s.cpuTimeNanos))")
                    }
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}
