import AppKit
import SwiftUI

enum ThermalColor {
    static func color(for state: ProcessInfo.ThermalState) -> NSColor {
        switch state {
        case .nominal: .systemGreen
        case .fair: .systemYellow
        case .serious, .critical: .systemRed
        @unknown default: .systemGray
        }
    }

    /// 仅主线程访问（UI 层）；缓存保证 NSImage 身份稳定，避免无谓的 label diff
    private static var dotCache: [ProcessInfo.ThermalState: NSImage] = [:]
    private static var flameCache: [ProcessInfo.ThermalState: NSImage] = [:]

    /// 8pt 彩色圆点 NSImage（isTemplate=false 保住颜色）
    static func dotImage(for state: ProcessInfo.ThermalState) -> NSImage {
        if let cached = dotCache[state] { return cached }
        let size = NSSize(width: 8, height: 8)
        let image = NSImage(size: size, flipped: false) { rect in
            color(for: state).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        dotCache[state] = image
        return image
    }

    /// 菜单栏火焰图标：颜色随热压力（菜单栏 label 会压扁 SwiftUI 颜色，
    /// 必须用 isTemplate=false 的染色 NSImage）
    static func flameImage(for state: ProcessInfo.ThermalState) -> NSImage {
        if let cached = flameCache[state] { return cached }
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "热压力")?
            .withSymbolConfiguration(config) else {
            return dotImage(for: state)
        }
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        symbol.draw(in: NSRect(origin: .zero, size: symbol.size))
        color(for: state).set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        flameCache[state] = tinted
        return tinted
    }
}

/// 菜单栏 label 的自观察壳：发布变化只重渲染这个小视图，
/// 不会触达 App body / MenuBarExtra scene
struct MenuBarStatusLabel: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        MenuBarLabel(
            thermalState: appState.thermalState,
            cpuPercent: appState.menuCPUPercent,
            memoryPercent: appState.menuMemoryPercent
        )
    }
}

struct MenuBarLabel: View {
    let thermalState: ProcessInfo.ThermalState
    let cpuPercent: Int?
    let memoryPercent: Int?

    /// ⚠️ MenuBarExtra label 落到 NSStatusItem 按钮，只支持一张图 + 一段文字：
    /// 多个 Image/Text 时第二组会被静默丢弃。因此火焰用唯一 Image，
    /// CPU% 与内存%（含 memorychip 符号）合进一个 Text（Text 内嵌 Image 插值
    /// 会进同一段 attributed title，不受限制）。
    var body: some View {
        HStack(spacing: 2) {
            Image(nsImage: ThermalColor.flameImage(for: thermalState))
            Text("\(cpuText) \(Image(systemName: "memorychip"))\(memText)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }

    private var cpuText: String { cpuPercent.map { "\($0)%" } ?? "–" }
    private var memText: String { memoryPercent.map { "\($0)%" } ?? "–" }
}
