<p align="center">
  <img src="assets/icon.png" width="128" alt="知热 icon" />
</p>

<h1 align="center">知热 Zhire</h1>

<p align="center">macOS 原生 · 低功耗 · 发热诊断菜单栏工具<br/>
<em>Mac 发烫的时候，3 秒内告诉你是谁在搞事。</em></p>

---

## 这是什么

Mac 突然变烫、风扇起飞，但你不知道是哪个应用在作怪？活动监视器藏得深、开着又重。

知热是一个常驻菜单栏的小工具：

- **菜单栏一眼概览**：🔥 火焰图标颜色跟随系统热压力（绿/黄/红）+ CPU 总占用% + 内存占用%
- **点开即答案**：下拉面板直接给出 CPU / 内存 Top 5 进程排行
- **发热诊断**：详情窗口按"CPU 时间消耗"排行全部进程——烧得越多越靠前，后台进程持续高 CPU 自动标红
- **进程列表**：可排序、可搜索、可强制退出（先 SIGTERM 给清理机会，再点升级 SIGKILL）
- **历史曲线**：CPU / 内存走势（仅窗口打开期间记录，保留最近 30 分钟）

## 为什么"低功耗"是卖点

监控工具自己不该成为发热源。知热的功耗模型：

| 状态 | 行为 | 实测 |
|------|------|------|
| 平时（面板关闭） | 仅每 10s 一次系统级采样（3 个轻量 syscall），无进程扫描、无后台线程 | **≈0.2% CPU** |
| 面板/窗口打开 | 每 2s 全量扫描进程，关闭立即停止 | ≈6%（与活动监视器同量级） |
| 锁屏/睡眠 | 采样全停，唤醒自动恢复 | 0 |

数据口径与活动监视器对齐：进程内存取 `phys_footprint`，CPU% 单核口径（多核可超 100%），热压力直接用系统 `thermalState`（发烫的最权威信号）。

零第三方依赖 · 零 TCC 权限弹窗 · 零 helper 进程 · 纯 Swift/SwiftUI。

## 安装

从 [Releases](../../releases) 下载最新 `Zhire-x.y.z.dmg`，拖进 Applications 即可。

DMG 已经过 Apple 公证（Notarized Developer ID），打开无任何 Gatekeeper 弹窗。

系统要求：macOS 14+。

## 自行构建

纯 SPM 工程，不需要 Xcode 工程文件：

```bash
git clone https://github.com/Zhanglala103838/zhire.git
cd zhire
swift test          # 34 个单元测试
swift run           # 开发运行（菜单栏出现图标）

# 打正式包需要自己的 Developer ID 证书：
export APPLE_SIGNING_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)"
./scripts/build-app.sh              # 构建+签名 → build/知热.app
./scripts/build-app.sh --notarize   # 另需 App Store Connect API Key（见脚本头部注释）
```

## 技术要点

写这个 app 时踩过、并且已经解决的坑（细节见 `docs/` 设计文档与 git 提交记录）：

- `proc_pid_rusage` 的时间字段是 **mach absolute time**，Apple Silicon 上不经 `mach_timebase_info` 换算 CPU% 会错约 41 倍
- `host_processor_info` 返回数组必须 `vm_deallocate`，否则周期轮询下稳定泄漏
- MenuBarExtra 的 App body 若用 `@StateObject` 订阅数据模型，任何发布都会拆建 status item → 菜单栏抖动 + 面板秒关；须用普通 `let` 单例 + 自观察 label 子视图
- MenuBarExtra label 只支持一张图 + 一段文字，多余的 Image/Text 被静默丢弃（合并进单 Text 的内嵌 Image 插值解决）
- pid 复用防御、毫秒级采样窗口的 CPU% 鬼值守卫、扫描循环禁止每 pid 一次 LaunchServices 查询（批量建表，CPU 减半）

## FAQ

**为什么不上 Mac App Store？**
MAS 强制 App Sandbox，而沙盒禁止读取其他进程的 CPU/内存信息（`proc_pid_rusage` 对其他进程返回 EPERM）、禁止 `kill`。这正是 iStat Menus、Stats 等工具都不在 App Store 的原因。

**内存百分比好像不动？**
macOS 内核会把内存占用维持在稳态，它本来就是慢变量（这也是"发烫看 CPU 不看内存"的原因）。1% ≈ 数百 MB，需要这个量级的净变化数字才会走一格。

**有全屏窗口时点菜单栏会闪一下？**
实测为 macOS 26+ 在存在全屏 Space 时的系统级渲染行为——任何 app 的菜单栏弹层（包括控制中心）都会闪，与知热无关，等系统更新修复。

## License

[MIT](LICENSE)
