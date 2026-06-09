import SwiftUI

@main
struct transApp: App {
    @StateObject private var appState = AppStateManager()

    var body: some Scene {
        MenuBarExtra("划词翻译", systemImage: "cursorarrow.motionlines") {
            MenuBarContentView()
                .environmentObject(appState)
        }

        Window("设置", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("翻译选中文本") {
            appState.handleHotKeyPressed()
        }
        .keyboardShortcut("z", modifiers: .option)

        Divider()

        Button("设置") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }

        Divider()

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
    }
}
