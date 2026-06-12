import SwiftUI

struct ProcessRowView: View {
    let sample: ProcessSample
    let icon: NSImage?
    /// .cpu 显示 CPU%，.memory 显示内存
    enum Metric { case cpu, memory }
    let metric: Metric

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            } else {
                Image(systemName: "gearshape").frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            }
            Text(sample.name).lineLimit(1).truncationMode(.middle)
            if sample.isSuspect {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.caption)
                    .help("后台进程持续高 CPU")
            }
            Spacer()
            Text(valueText)
                .font(.system(.body).monospacedDigit())
                .foregroundStyle(sample.isSuspect ? .red : .primary)
        }
    }

    private var valueText: String {
        switch metric {
        case .cpu:
            if let pct = sample.cpuPercent { return String(format: "%.1f%%", pct) }
            return ByteFormat.cpuTime(sample.cpuTimeNanos)  // 首帧显示累计 CPU 时间
        case .memory:
            return ByteFormat.memory(sample.memoryBytes)
        }
    }
}
