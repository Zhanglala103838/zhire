import SwiftUI

struct ProcessListView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\ProcessSample.memoryBytes, order: .reverse)]
    @State private var searchText = ""
    @State private var selection: Set<pid_t> = []
    @State private var terminator = ProcessTerminator()

    private var rows: [ProcessSample] {
        let filtered = searchText.isEmpty
            ? appState.processes
            : appState.processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("名称", value: \.name) { s in
                    HStack(spacing: 4) {
                        Text(s.name)
                        if s.isSuspect {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red).font(.caption)
                        }
                    }
                }
                TableColumn("PID") { s in
                    Text("\(s.pid)").monospacedDigit()
                }
                .width(60)
                TableColumn("CPU %", value: \.sortableCPUPercent) { s in
                    Text(s.cpuPercent.map { String(format: "%.1f", $0) } ?? "–")
                        .monospacedDigit()
                }
                .width(70)
                TableColumn("内存", value: \.memoryBytes) { s in
                    Text(ByteFormat.memory(s.memoryBytes)).monospacedDigit()
                }
                .width(90)
            }
            HStack {
                TextField("搜索进程名", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Spacer()
                Button("强制退出", role: .destructive) {
                    for pid in selection { terminator.terminate(pid: pid) }
                }
                .disabled(selection.isEmpty)
                .help("第一次发 SIGTERM；再次点击对同一进程升级 SIGKILL")
            }
            .padding(8)
        }
    }
}

extension ProcessSample {
    /// Table 排序用：nil 当 -1 沉底
    var sortableCPUPercent: Double { cpuPercent ?? -1 }
}
