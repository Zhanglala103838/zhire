import Charts
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("仅窗口打开期间记录，保留最近 30 分钟")
                .font(.caption).foregroundStyle(.secondary)

            GroupBox("CPU 总占用 %") {
                Chart(appState.historyPoints) { p in
                    LineMark(x: .value("时间", p.timestamp), y: .value("CPU", p.cpuPercent))
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: 0...100)
                .frame(minHeight: 140)
            }

            GroupBox("物理内存占用 %（近似口径）") {
                Chart(appState.historyPoints) { p in
                    LineMark(x: .value("时间", p.timestamp), y: .value("内存", p.memoryUsedFraction * 100))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(p.pressure == .normal ? Color.blue : Color.red)
                }
                .chartYScale(domain: 0...100)
                .frame(minHeight: 140)
            }

            if appState.historyPoints.isEmpty {
                Text("采样中，约 2 秒出第一个点…")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding()
    }
}
