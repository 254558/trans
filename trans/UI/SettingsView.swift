import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var apiKey: String = ""
    @State private var autoCopy: Bool = true
    @State private var saveStatus: String?
    @State private var isSaveError = false

    var body: some View {
        Form {
            Section("DeepSeek API 配置") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("保存") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let status = saveStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(isSaveError ? .red : .green)
                    }
                }
            }

            Section("偏好设置") {
                Toggle("自动复制翻译结果", isOn: $autoCopy)
            }

            Section("快捷键") {
                HStack {
                    Text("翻译选中文本")
                    Spacer()
                    Text("⌥ + Z")
                        .font(.body.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Section("所需权限") {
                Group {
                    PermissionRow(
                        title: "输入监控",
                        description: "检测 ⌥ + Z 快捷键",
                        granted: appState.isInputMonitoringGranted,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring"
                    )
                    PermissionRow(
                        title: "辅助功能",
                        description: "读取选中文本",
                        granted: appState.isAccessibilityTrusted,
                        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    )
                }
                if !appState.isInputMonitoringGranted {
                    Text("授权后在设置页面点击 ⌥ + Z 测试")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button("检查权限状态") {
                    appState.refreshPermissions()
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 440)
        .onAppear {
            if let key = try? KeychainManager.read(key: "deepseek_api_key") {
                apiKey = key
            }
            autoCopy = AppConfig.isAutoCopyEnabled
        }
        .onChange(of: autoCopy) { newValue in
            AppConfig.isAutoCopyEnabled = newValue
        }
    }

    private func save() {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        do {
            try AppConfig.saveAPIKey(key)
            saveStatus = "已保存"
            isSaveError = false
        } catch {
            saveStatus = "保存失败: \(error.localizedDescription)"
            isSaveError = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveStatus = nil
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let granted: Bool
    let settingsURL: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if granted {
                Label("已授权", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Button("去设置") {
                    if let url = URL(string: settingsURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }
}
