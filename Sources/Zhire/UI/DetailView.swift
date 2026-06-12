import SwiftUI

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DiagnosisView().tabItem { Label("发热诊断", systemImage: "flame") }
            ProcessListView().tabItem { Label("进程列表", systemImage: "list.bullet") }
            HistoryView().tabItem { Label("历史曲线", systemImage: "chart.xyaxis.line") }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear { appState.windowDidAppear() }
        .onDisappear { appState.windowDidDisappear() }
    }
}
