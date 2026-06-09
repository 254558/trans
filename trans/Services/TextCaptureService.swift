import Cocoa
import ApplicationServices

struct TextCaptureService {

    func captureSelectedText() -> String? {
        guard AXIsProcessTrusted() else { return nil }

        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1.5)

        // 方案1: Accessibility API 直接读取
        if let text = captureDirectly(appElement: appElement) {
            return text
        }

        // 方案2: 复制到剪贴板后读取
        if let text = captureViaClipboard(pid: pid) {
            return text
        }

        return nil
    }

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Private

    private func captureDirectly(appElement: AXUIElement) -> String? {
        // 尝试应用级别的选中文本
        var appSelectedText: CFTypeRef?
        let appTextErr = AXUIElementCopyAttributeValue(
            appElement,
            kAXSelectedTextAttribute as CFString,
            &appSelectedText
        )
        if appTextErr == .success, let text = appSelectedText as? String, !text.isEmpty {
            return text
        }

        // 尝试焦点元素的选中文本
        var focused: CFTypeRef?
        let focusedErr = AXUIElementCopyAttributeValue(
            appElement,
            "AXFocusedUIElement" as CFString,
            &focused
        )

        if focusedErr == .success, let focusedElement = focused {
            let uiElement = focusedElement as! AXUIElement

            var selectedText: CFTypeRef?
            let textErr = AXUIElementCopyAttributeValue(
                uiElement,
                "AXSelectedText" as CFString,
                &selectedText
            )
            if textErr == .success, let text = selectedText as? String, !text.isEmpty {
                return text
            }

            var value: CFTypeRef?
            let valueErr = AXUIElementCopyAttributeValue(
                uiElement,
                kAXValueAttribute as CFString,
                &value
            )
            if valueErr == .success, let text = value as? String, !text.isEmpty {
                return text
            }
        }

        return nil
    }

    /// 保存剪贴板 → 发送 Cmd+C 到目标进程 → 读取 → 恢复
    private func captureViaClipboard(pid: pid_t) -> String? {
        let pasteboard = NSPasteboard.general

        // 保存用户剪贴板字符串
        let savedString = pasteboard.string(forType: .string)
        let savedChangeCount = pasteboard.changeCount

        // 向目标进程发送 Cmd+C 键盘事件
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        if let down = keyDown, let up = keyUp {
            down.postToPid(pid)
            up.postToPid(pid)
        }

        // 轮询等待剪贴板变化（最长 500ms）
        var text: String?
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.05)
            guard pasteboard.changeCount != savedChangeCount else { continue }
            text = pasteboard.string(forType: .string)
            if let t = text, !t.isEmpty { break }
        }

        // 恢复用户剪贴板
        pasteboard.clearContents()
        if let original = savedString {
            pasteboard.setString(original, forType: .string)
        }

        return text
    }
}
