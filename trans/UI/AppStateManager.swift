import Combine
import SwiftUI

@MainActor
class AppStateManager: ObservableObject {
    @Published var isAccessibilityTrusted: Bool = false
    @Published var isInputMonitoringGranted: Bool = false

    private let hotKeyService = HotKeyService()
    private let textCapture = TextCaptureService()
    private var currentTask: Task<Void, Never>?

    init() {
        hotKeyService.onHotKeyPressed = { [weak self] in
            self?.handleHotKeyPressed()
        }
        hotKeyService.register()
        isInputMonitoringGranted = hotKeyService.isGranted
        isAccessibilityTrusted = textCapture.isTrusted
    }

    func handleHotKeyPressed() {
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self = self else { return }

            let cursorPos = NSEvent.mouseLocation

            isInputMonitoringGranted = hotKeyService.isGranted
            isAccessibilityTrusted = textCapture.isTrusted

            guard isAccessibilityTrusted else {
                FloatingPanelManager.shared.showError("请在系统设置中授予辅助功能权限", at: cursorPos)
                return
            }

            guard AppConfig.hasAPIKey else {
                FloatingPanelManager.shared.showError("请在设置中输入 DeepSeek API Key", at: cursorPos)
                return
            }

            FloatingPanelManager.shared.showLoading(at: cursorPos)

            let selectedText = await Task.detached(priority: .userInitiated) {
                self.textCapture.captureSelectedText()
            }.value

            guard !Task.isCancelled else { return }

            guard let text = selectedText, !text.isEmpty else {
                FloatingPanelManager.shared.showError("无法获取选中文本，请确保已选中文本并授予辅助功能权限", at: cursorPos)
                return
            }

            do {
                let result = try await TranslationService.shared.translate(text)

                guard !Task.isCancelled else { return }

                if AppConfig.isAutoCopyEnabled {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.translation, forType: .string)
                }

                FloatingPanelManager.shared.show(result: result, at: cursorPos)
            } catch {
                guard !Task.isCancelled else { return }
                FloatingPanelManager.shared.showError(error.localizedDescription, at: cursorPos)
            }
        }
    }

    func refreshPermissions() {
        isAccessibilityTrusted = textCapture.isTrusted
        hotKeyService.register()
        isInputMonitoringGranted = hotKeyService.isGranted
    }
}
