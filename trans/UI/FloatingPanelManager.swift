import Cocoa
import SwiftUI

@MainActor
final class FloatingPanelManager {
    static let shared = FloatingPanelManager()

    private let panel: NSPanel
    private let hostingView: NSHostingView<FloatingPanelView>
    private let viewModel = PanelViewModel()

    private var mouseMonitor: Any?
    private var keyboardMonitor: Any?

    private let panelWidth: CGFloat = 420

    private init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // Dark rounded container
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.autoresizingMask = [.width, .height]

        hostingView = NSHostingView(rootView: FloatingPanelView(viewModel: viewModel))
        hostingView.autoresizingMask = [.width, .height]

        container.frame = panel.contentView?.bounds ?? .zero
        hostingView.frame = container.bounds
        container.addSubview(hostingView)
        panel.contentView = container

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            let click = NSEvent.mouseLocation
            if !self.panel.frame.contains(click) {
                self.dismiss()
            }
        }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, let self, self.panel.isVisible {
                self.dismiss()
                return nil
            }
            return event
        }
    }

    deinit {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let k = keyboardMonitor { NSEvent.removeMonitor(k) }
    }

    func showLoading(at screenPoint: NSPoint) { show(state: .loading, at: screenPoint) }
    func show(result: TranslationResult, at screenPoint: NSPoint) { show(state: .result(result), at: screenPoint) }
    func showError(_ message: String, at screenPoint: NSPoint? = nil) {
        show(state: .error(message), at: screenPoint ?? NSEvent.mouseLocation)
    }
    func dismiss() { panel.orderOut(nil) }

    private func show(state: PanelViewModel.State, at screenPoint: NSPoint) {
        viewModel.state = state
        hostingView.layoutSubtreeIfNeeded()

        let measured = hostingView.fittingSize
        let contentHeight = max(measured.height, 80)

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) }) ?? NSScreen.main else {
            panel.setFrame(NSRect(origin: screenPoint, size: NSSize(width: panelWidth, height: contentHeight)), display: true)
            panel.orderFrontRegardless()
            return
        }

        let maxHeight = screen.visibleFrame.height * 0.8
        let panelHeight = min(contentHeight, maxHeight)
        let panelSize = NSSize(width: panelWidth, height: panelHeight)

        let visible = screen.visibleFrame
        var x = screenPoint.x + 15
        var y = screenPoint.y - panelSize.height - 10

        if x + panelSize.width > visible.maxX { x = visible.maxX - panelSize.width - 10 }
        if x < visible.minX { x = visible.minX + 10 }
        if y < visible.minY { y = screenPoint.y + 20 }

        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: true)
        panel.orderFrontRegardless()
    }
}
