#!/usr/bin/env swift
// 生成知热 app icon：暖色渐变 squircle + 白色火焰
// 用法：swift scripts/generate-icon.swift（在 repo 根目录执行）
// 产出：build/AppIcon.iconset/*.png → Resources/AppIcon.icns（由 iconutil 转换）

import AppKit

let iconsetDir = "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let s = CGFloat(pixels)
    // macOS 圆角矩形图标规范：内容占 824/1024，四周烘焙透明边距，不满铺
    let inset = s * 100.0 / 1024.0
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = s * 185.4 / 1024.0
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // 暖色渐变：顶部暖橙 → 底部深红（"知热"）
    NSGradient(colors: [
        NSColor(calibratedRed: 1.00, green: 0.52, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.80, green: 0.11, blue: 0.20, alpha: 1),
    ])!.draw(in: squircle, angle: -90)

    // 白色火焰（SF Symbol），居中，约占内容区一半
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.45, weight: .medium)
    if let flame = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let fs = flame.size
        let target = s * 0.50
        let scale = target / max(fs.width, fs.height)
        let dw = fs.width * scale
        let dh = fs.height * scale
        let drawRect = NSRect(x: (s - dw) / 2, y: (s - dh) / 2, width: dw, height: dh)
        // 先画符号再用 sourceAtop 染白
        let tinted = NSImage(size: fs)
        tinted.lockFocus()
        flame.draw(in: NSRect(origin: .zero, size: fs))
        NSColor.white.set()
        NSRect(origin: .zero, size: fs).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    return rep
}

// iconset 命名规范：基础尺寸 + @2x
let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for entry in entries {
    let rep = renderIcon(pixels: entry.pixels)
    let png = rep.representation(using: .png, properties: [:])!
    let path = "\(iconsetDir)/\(entry.name).png"
    try! png.write(to: URL(fileURLWithPath: path))
    print("✓ \(path)")
}
print("done — 接下来跑 iconutil -c icns \(iconsetDir) -o Resources/AppIcon.icns")
