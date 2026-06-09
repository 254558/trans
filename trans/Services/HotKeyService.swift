import Cocoa

final class HotKeyService {
    var onHotKeyPressed: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var isGranted: Bool = false

    func register() {
        // 如果已创建过，先清理
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            isGranted = false
            print("Input Monitoring not granted - cannot register hotkey")
            return
        }

        isGranted = true
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }
}

private let hotKeyCallback: CGEventTapCallBack = { _, _, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // ⌥ + Z (keyCode 6 = kVK_ANSI_Z)
    if keyCode == 6, flags.contains(.maskAlternate) {
        let service = Unmanaged<HotKeyService>.fromOpaque(refcon).takeUnretainedValue()
        DispatchQueue.main.async {
            service.onHotKeyPressed?()
        }
    }

    return Unmanaged.passUnretained(event)
}
