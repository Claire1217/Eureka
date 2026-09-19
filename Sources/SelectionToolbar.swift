import Cocoa

/// Minimal floating toolbar that appears when text is selected.
/// A single small blue dot, nothing else: click it to open the capture panel with the selection attached.
/// Can be turned off in Settings (UserDefaults key "selectionToolbarEnabled").
class SelectionToolbar {
    private var window: NSWindow?
    private var mouseDownPos: NSPoint?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var hideTimer: Timer?

    var onExpand: ((String, NSPoint) -> Void)?  // open capture panel

    private let dotSize: CGFloat = 14
    private let toolbarW: CGFloat = 24   // dot + room for its shadow
    private let toolbarH: CGFloat = 24

    func startMonitoring() {
        // Track mouseDown position to distinguish click vs drag-select
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.mouseDownPos = NSEvent.mouseLocation
            self?.dismiss()
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self = self else { return }
            let upPos = NSEvent.mouseLocation
            guard let downPos = self.mouseDownPos else { return }

            // Only trigger on drag-select (distance > 20px), not clicks
            let dx = upPos.x - downPos.x
            let dy = upPos.y - downPos.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 20 else { return }

            // Wait a moment for the selection to register
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.checkAndShow(at: upPos)
            }
        }
    }

    /// Defaults to on; users can disable the dot in Settings.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "selectionToolbarEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "selectionToolbarEnabled") }
    }

    private func checkAndShow(at pos: NSPoint) {
        guard SelectionToolbar.isEnabled else { return }
        // Don't show if capture panel is open
        if let delegate = NSApp.delegate as? AppDelegate,
           delegate.capturePanel?.isOpen == true { return }

        guard AXIsProcessTrusted() else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let pid = frontApp.processIdentifier
        let appEl = AXUIElementCreateApplication(pid)
        var focused: AnyObject?
        let r1 = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focused)
        guard r1 == .success, let el = focused else { return }

        var sel: AnyObject?
        let r2 = AXUIElementCopyAttributeValue(el as! AXUIElement, kAXSelectedTextAttribute as CFString, &sel)
        guard r2 == .success, let text = sel as? String else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        show(at: pos, selectedText: trimmed)
    }

    private func show(at mousePos: NSPoint, selectedText: String) {
        dismiss()
        // Use the screen the mouse is on, not NSScreen.main — they differ on multi-monitor setups
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mousePos, $0.frame, false) })
                ?? NSScreen.main else { return }
        let vis = screen.visibleFrame

        // Position: slightly below and right of mouse
        var x = mousePos.x + 8
        var y = mousePos.y - toolbarH - 8

        // Keep on screen
        if x + toolbarW > vis.maxX - 10 { x = mousePos.x - toolbarW - 8 }
        if y < vis.minY + 10 { y = mousePos.y + 8 }

        let win = NSWindow(contentRect: NSMakeRect(x, y, toolbarW, toolbarH),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false

        // Just the dot: a transparent window with nothing but the small blue circle
        let container = NSView(frame: NSMakeRect(0, 0, toolbarW, toolbarH))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let inset = (toolbarH - dotSize) / 2
        let dotBtn = ClickableRow(frame: NSMakeRect(inset, inset, dotSize, dotSize))
        let dotLayer = CAGradientLayer()
        dotLayer.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        dotLayer.cornerRadius = dotSize / 2
        dotLayer.colors = [
            NSColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1).cgColor,
            NSColor(red: 0.38, green: 0.50, blue: 0.85, alpha: 1).cgColor
        ]
        dotLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        dotLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        dotBtn.wantsLayer = true
        dotBtn.layer?.cornerRadius = dotSize / 2
        dotBtn.layer?.masksToBounds = false
        // Soft shadow so the dot stays visible on any background
        dotBtn.layer?.shadowColor = NSColor.black.cgColor
        dotBtn.layer?.shadowOpacity = 0.18
        dotBtn.layer?.shadowRadius = 3
        dotBtn.layer?.shadowOffset = CGSize(width: 0, height: -1)
        dotBtn.layer?.addSublayer(dotLayer)
        let text = selectedText
        let pos = mousePos
        dotBtn.onClick = { [weak self] in
            self?.dismiss()
            self?.onExpand?(text, pos)
        }
        container.addSubview(dotBtn)

        win.contentView = container

        // Fade in
        container.alphaValue = 0
        win.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            container.animator().alphaValue = 1
        }

        self.window = win

        // Auto-hide after 4 seconds
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }

    func dismiss() {
        hideTimer?.invalidate()
        hideTimer = nil
        window?.orderOut(nil)
        window = nil
    }

    private func fadeOut() {
        guard let win = window, let content = win.contentView else {
            dismiss()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            content.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.dismiss()
        })
    }
}
