import SwiftUI

@main
struct ZhireApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// ⚠️ 必须是普通 let（不是 @StateObject/@ObservedObject）：
    /// App body 一旦订阅 AppState，任何 @Published 发布都会重算 MenuBarExtra scene，
    /// AppKit 随之拆建 status item → 菜单栏抖动 + 呈现中的面板被收掉
    private let appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(appState)
        } label: {
            MenuBarStatusLabel()
        }
        .menuBarExtraStyle(.window)

        Window("知热", id: "detail") {
            DetailView().environmentObject(appState)
        }
        .defaultSize(width: 760, height: 520)
    }
}
