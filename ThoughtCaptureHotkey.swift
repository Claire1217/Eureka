import Cocoa
import Carbon

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Configuration
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

let HOTKEY_KEYCODE: UInt32 = 17          // 'T' key
let HOTKEY_SCREENSHOT: UInt32 = 15       // 'R' key
let HOTKEY_MODIFIERS: UInt32 = UInt32(optionKey)  // Option (⌥)

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Local Storage (no server needed)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

let THOUGHT_COLORS = ["coral", "blue", "purple", "green", "amber", "olive", "pink", "steel"]

class LocalStorage {
    static let shared = LocalStorage()
    private var colorIndex = 0

    var vaultPath: String {
        get { UserDefaults.standard.string(forKey: "vaultPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "vaultPath") }
    }

    var backend: String {
        get { UserDefaults.standard.string(forKey: "storageBackend") ?? "obsidian" }
        set {
            UserDefaults.standard.set(newValue, forKey: "storageBackend")
            ResultBubble.storageBackend = newValue
        }
    }

    func nextColor() -> String {
        let c = THOUGHT_COLORS[colorIndex % THOUGHT_COLORS.count]
        colorIndex = (colorIndex + 1) % THOUGHT_COLORS.count
        return c
    }

    func save(thought: String, selectedText: String, appName: String,
              browserURL: String, screenshotPath: String?) -> (ok: Bool, savedTo: String) {
        if backend == "notes" {
            return saveToAppleNotes(thought: thought, selectedText: selectedText, appName: appName)
        } else {
            return saveToObsidian(thought: thought, selectedText: selectedText,
                                  appName: appName, browserURL: browserURL,
                                  screenshotPath: screenshotPath)
        }
    }

    private func saveToObsidian(thought: String, selectedText: String,
                                appName: String, browserURL: String,
                                screenshotPath: String?) -> (ok: Bool, savedTo: String) {
        guard !vaultPath.isEmpty else { return (false, "") }
        let vault = NSString(string: vaultPath).expandingTildeInPath
        let fm = FileManager.default

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: Date())
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        let timeStr = tf.string(from: Date())

        let dayDir = "\(vault)/01_daily/\(dateStr)"
        try? fm.createDirectory(atPath: dayDir, withIntermediateDirectories: true)

        let filePath = "\(dayDir)/Daily random thoughts.md"
        let savedTo = "01_daily/\(dateStr)/Daily random thoughts.md"

        // Build source line
        var source = ""
        if !browserURL.isEmpty, !browserURL.hasPrefix("app://"),
           let parsed = URL(string: browserURL) {
            let host = parsed.host ?? ""
            let path = parsed.path.count <= 40 ? parsed.path : String(parsed.path.prefix(37)) + "..."
            source = "[\(host)\(path)](\(browserURL))"
        }

        // Screenshot
        var screenshotFilename: String? = nil
        if let path = screenshotPath, let data = fm.contents(atPath: path) {
            let ts = DateFormatter()
            ts.dateFormat = "yyyyMMdd_HHmmss"
            screenshotFilename = "tc_\(ts.string(from: Date())).png"
            let attachDir = "\(vault)/attachments"
            try? fm.createDirectory(atPath: attachDir, withIntermediateDirectories: true)
            fm.createFile(atPath: "\(attachDir)/\(screenshotFilename!)", contents: data)
            try? fm.removeItem(atPath: path)
        }

        let color = nextColor()
        var lines = [String]()
        lines.append("")
        lines.append("> [!thought-\(color)] \(timeStr)")
        lines.append("> \(thought)")
        if let sf = screenshotFilename {
            lines.append("> ![[\(sf)]]")
        }
        if !selectedText.isEmpty {
            var safe = selectedText
            // Sanitize content that breaks Obsidian callout nesting
            safe = safe.replacingOccurrences(of: "```", with: "` ` `")
            let quoted = safe.components(separatedBy: "\n").joined(separator: "\n> > ")
            let sourceTag = !source.isEmpty ? " 【\(source)】" : (!appName.isEmpty ? " 【\(appName)】" : "")
            lines.append("> > \(quoted)\(sourceTag)")
        } else if !source.isEmpty {
            lines.append("> \(source)")
        }
        lines.append("")

        let entry = lines.joined(separator: "\n")

        if fm.fileExists(atPath: filePath) {
            if let fh = FileHandle(forWritingAtPath: filePath) {
                fh.seekToEndOfFile()
                fh.write(entry.data(using: .utf8)!)
                fh.closeFile()
            }
        } else {
            let header = "# Random Thoughts — \(dateStr)\n"
            try? (header + entry).write(toFile: filePath, atomically: true, encoding: .utf8)
        }

        return (true, savedTo)
    }

    private func saveToAppleNotes(thought: String, selectedText: String,
                                  appName: String) -> (ok: Bool, savedTo: String) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: Date())
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"
        let timeStr = tf.string(from: Date())
        let noteTitle = "Thoughts — \(dateStr)"

        var body = "🔵 \(timeStr)<br>\(thought)"
        if !selectedText.isEmpty {
            let sourceTag = !appName.isEmpty ? " <span style=\"font-style:normal;font-size:0.8em\">— \(appName)</span>" : ""
            body += "<br><span style=\"font-style:italic;color:#8e8e93\">\(selectedText)\(sourceTag)</span>"
        }
        let escaped = body.replacingOccurrences(of: "\"", with: "\\\"")
                          .replacingOccurrences(of: "\n", with: "<br>")

        let script = """
        tell application "Notes"
            set noteFound to false
            repeat with n in notes of default account
                if name of n is "\(noteTitle)" then
                    set body of n to (body of n) & "<br><br>" & "\(escaped)"
                    set noteFound to true
                    exit repeat
                end if
            end repeat
            if not noteFound then
                make new note at default account with properties {name:"\(noteTitle)", body:"\(escaped)"}
            end if
        end tell
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        do {
            try proc.run()
            proc.waitUntilExit()
            return (proc.terminationStatus == 0, noteTitle)
        } catch {
            fputs("[TC] Apple Notes error: \(error)\n", stderr)
            return (false, "")
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Design Tokens
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct TC {
    static let green  = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1)
    static let red    = NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1)
    // text hierarchy: primary → body → secondary → hint
    static let primary = NSColor(white: 0.06, alpha: 1)   // question — loudest
    static let text    = NSColor(white: 0.13, alpha: 1)
    static let body    = NSColor(white: 0.24, alpha: 1)    // answer — readable
    static let sub     = NSColor(white: 0.40, alpha: 1)    // input text
    static let muted   = NSColor(white: 0.55, alpha: 1)    // context quote
    static let faint   = NSColor(white: 0.72, alpha: 1)    // hint
    static let rule    = NSColor(white: 0, alpha: 0.07)
    static let ctxBg   = NSColor(white: 0, alpha: 0.035)   // context block background
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App Delegate
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var hotKeyScreenshotRef: EventHotKeyRef?
    var capturePanel: CapturePanel?
    var resultBubble: ResultBubble?
    var selectionToolbar: SelectionToolbar?
    var prevAppBundleId: String?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let trusted = AXIsProcessTrusted()
        fputs("[TC] AX trusted on launch: \(trusted)\n", stderr)

        setupMenubar()
        registerHotkey()
        resultBubble = ResultBubble()
        ResultBubble.fetchConfig(sync: true)
        setupSelectionToolbar()
    }

    func setupSelectionToolbar() {
        selectionToolbar = SelectionToolbar()

        // Pin: save selected text directly as thought
        selectionToolbar?.onPin = { [weak self] text in
            self?.sendToServer(thought: text, selectedText: "",
                               appName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown",
                               windowTitle: self?.getWindowTitle() ?? "",
                               browserURL: "")
        }

        // Expand: open capture panel with selected text
        selectionToolbar?.onExpand = { [weak self] text, pos in
            guard let self = self else { return }
            self.prevAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
            let windowTitle = self.getWindowTitle()
            let browserURL = self.getBrowserURL(appName: appName)
            let editable = self.lastSelectionEditable

            if self.capturePanel == nil { self.capturePanel = CapturePanel() }
            self.capturePanel?.show(selectedText: text, anchorPoint: pos) { [weak self] thought in
                self?.sendToServer(thought: thought, selectedText: text,
                                   appName: appName, windowTitle: windowTitle,
                                   browserURL: browserURL, editable: editable)
            }
        }

        selectionToolbar?.startMonitoring()
    }

    // MARK: Menubar

    func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "TC"

        let menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture Thought (\u{2325}T)",
                                     action: #selector(triggerCapture), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)
        let screenshotItem = NSMenuItem(title: "Screenshot + Comment (\u{2325}R)",
                                        action: #selector(triggerScreenshot), keyEquivalent: "")
        screenshotItem.target = self
        menu.addItem(screenshotItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: Global Hotkey (Carbon)

    func registerHotkey() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)

        InstallEventHandler(
            GetApplicationEventTarget(), hotKeyHandler, 1, &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)

        // ⌥T — thought capture
        var hotKeyID1 = EventHotKeyID()
        hotKeyID1.signature = OSType(0x54435F48)  // "TC_H"
        hotKeyID1.id = 1
        RegisterEventHotKey(HOTKEY_KEYCODE, HOTKEY_MODIFIERS, hotKeyID1,
                            GetApplicationEventTarget(), 0, &hotKeyRef)

        // ⌥R — screenshot + comment
        var hotKeyID2 = EventHotKeyID()
        hotKeyID2.signature = OSType(0x54435F48)
        hotKeyID2.id = 2
        RegisterEventHotKey(HOTKEY_SCREENSHOT, HOTKEY_MODIFIERS, hotKeyID2,
                            GetApplicationEventTarget(), 0, &hotKeyScreenshotRef)
    }

    // MARK: Capture Flow

    @objc func triggerCapture() {
        let prevApp = NSWorkspace.shared.frontmostApplication
        prevAppBundleId = prevApp?.bundleIdentifier

        let mousePos = NSEvent.mouseLocation
        let selectedText = getSelectedText()
        let editable = lastSelectionEditable
        let appName = prevApp?.localizedName ?? "Unknown"
        let windowTitle = getWindowTitle()
        let browserURL = getBrowserURL(appName: appName)

        if capturePanel == nil { capturePanel = CapturePanel() }
        capturePanel?.show(selectedText: selectedText, anchorPoint: mousePos) { [weak self] thought in
            self?.sendToServer(thought: thought, selectedText: selectedText,
                               appName: appName, windowTitle: windowTitle, browserURL: browserURL,
                               editable: editable)
        }
    }

    // MARK: Screenshot Capture Flow (⌥R)

    @objc func triggerScreenshot() {
        let prevApp = NSWorkspace.shared.frontmostApplication
        let appName = prevApp?.localizedName ?? "Unknown"
        let windowTitle = getWindowTitle()
        let browserURL = getBrowserURL(appName: appName)

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let tmpPath = "/tmp/tc_screenshot_\(timestamp).png"

        // Force previous app to front via AppleScript (more reliable than activate)
        if let bundleId = prevApp?.bundleIdentifier {
            _ = runOsascript(
                "tell application id \"\(bundleId)\" to activate")
        }

        // Wait until the app is actually frontmost, then screenshot
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Poll until previous app is frontmost (max 1s)
            for _ in 0..<20 {
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    == prevApp?.bundleIdentifier { break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            Thread.sleep(forTimeInterval: 0.15)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-i", "-x", tmpPath]
            try? proc.run()
            proc.waitUntilExit()

            DispatchQueue.main.async {
                guard FileManager.default.fileExists(atPath: tmpPath) else { return }
                let mousePos = NSEvent.mouseLocation
                if self?.capturePanel == nil { self?.capturePanel = CapturePanel() }
                self?.capturePanel?.show(selectedText: "", anchorPoint: mousePos,
                                        screenshotPath: tmpPath) { thought in
                    self?.sendToServer(thought: thought, selectedText: "",
                                       appName: appName, windowTitle: windowTitle,
                                       browserURL: browserURL, screenshotPath: tmpPath)
                }
            }
        }
    }

    // MARK: Selected Text (Accessibility API + Cmd+C fallback)

    var lastSelectionEditable: Bool = false

    func getSelectedText() -> String {
        func dbg(_ msg: String) { fputs("[TC] \(msg)\n", stderr) }

        let trusted = AXIsProcessTrusted()
        lastSelectionEditable = false

        // Method 1: Accessibility API (if permitted)
        if trusted {
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                let pid = frontApp.processIdentifier
                let appEl = AXUIElementCreateApplication(pid)
                var focused: AnyObject?
                let r1 = AXUIElementCopyAttributeValue(appEl, kAXFocusedUIElementAttribute as CFString, &focused)
                if r1 == .success, let el = focused {
                    // Check if the focused element is editable
                    let axEl = el as! AXUIElement
                    var roleVal: AnyObject?
                    AXUIElementCopyAttributeValue(axEl, kAXRoleAttribute as CFString, &roleVal)
                    let role = roleVal as? String ?? ""
                    let editableRoles = ["AXTextField", "AXTextArea", "AXComboBox"]
                    if editableRoles.contains(role) {
                        lastSelectionEditable = true
                    } else {
                        // Some apps use AXWebArea but contenteditable
                        var editableVal: AnyObject?
                        let r3 = AXUIElementCopyAttributeValue(axEl, "AXEditable" as CFString, &editableVal)
                        if r3 == .success, let editable = editableVal as? Bool, editable {
                            lastSelectionEditable = true
                        }
                    }
                    dbg("role=\(role) editable=\(lastSelectionEditable)")

                    var sel: AnyObject?
                    let r2 = AXUIElementCopyAttributeValue(axEl, kAXSelectedTextAttribute as CFString, &sel)
                    if r2 == .success, let text = sel as? String {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            dbg("Got selected text via AX (editable=\(lastSelectionEditable))")
                            return trimmed
                        }
                    }
                }
            }
        }

        // Method 2: CGEvent Cmd+C (needs Accessibility permission)
        if trusted {
            let pb = NSPasteboard.general
            let oldCount = pb.changeCount
            let src = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
            down?.flags = .maskCommand; up?.flags = .maskCommand
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
            usleep(200_000)

            if pb.changeCount != oldCount {
                let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !text.isEmpty {
                    dbg("Got context from clipboard (\(text.count) chars)")
                    return text
                }
            }
        }

        // Fallback: read clipboard directly (user can Cmd+C before ⌥T)
        let clipText = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !clipText.isEmpty && clipText.count < 2000 {
            dbg("Got context from clipboard fallback (\(clipText.count) chars)")
            return clipText
        }

        dbg("No selected text found")
        return ""
    }

    // MARK: Context Helpers

    func getBrowserURL(appName: String) -> String {
        let script: String
        switch appName {
        case "Safari":
            script = "tell application \"Safari\" to get URL of current tab of front window"
        case "Google Chrome", "Microsoft Edge", "Brave Browser", "Arc":
            script = "tell application \"\(appName)\" to get URL of active tab of front window"
        default: return ""
        }
        return runOsascript(script)
    }

    func getWindowTitle() -> String {
        return runOsascript(
            "tell application \"System Events\" to get name of first window " +
            "of (first process whose frontmost is true)")
    }

    private func runOsascript(_ script: String) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        let deadline = DispatchTime.now() + .seconds(2)
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            proc.waitUntilExit()
            done.signal()
        }
        if done.wait(timeout: deadline) == .timedOut {
            proc.terminate()
            fputs("[TC] osascript timed out\n", stderr)
            return ""
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: Save Thought

    func sendToServer(thought: String, selectedText: String,
                      appName: String, windowTitle: String, browserURL: String,
                      editable: Bool = false, screenshotPath: String? = nil) {
        // Strip "/" prefix — lite version treats all input as thought
        var cleanThought = thought
        if cleanThought.hasPrefix("/") || cleanThought.hasPrefix("／") {
            cleanThought = String(cleanThought.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        if cleanThought.isEmpty && selectedText.isEmpty { return }

        let result = LocalStorage.shared.save(
            thought: cleanThought, selectedText: selectedText,
            appName: appName, browserURL: browserURL,
            screenshotPath: screenshotPath)

        capturePanel?.close()
        resultBubble?.addItem(text: cleanThought, savedTo: result.savedTo, ok: result.ok)
    }
}

// Carbon callback — dispatches ⌥T (id=1) or ⌥R (id=2) to AppDelegate
func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?,
                   userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let ud = userData, let ev = event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    GetEventParameter(ev, EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID), nil,
                      MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    let delegate = Unmanaged<AppDelegate>.fromOpaque(ud).takeUnretainedValue()
    let sel: Selector = hotKeyID.id == 2
        ? #selector(AppDelegate.triggerScreenshot)
        : #selector(AppDelegate.triggerCapture)
    delegate.performSelector(onMainThread: sel, with: nil, waitUntilDone: false)
    return noErr
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Capture Panel
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// NSPanel subclass that accepts keyboard input despite borderless style.
class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Floating input bar — appears near selected text, captures a thought.
/// Uses NSTextView for auto-wrapping multi-line input.
class CapturePanel: NSObject, NSTextStorageDelegate {
    private var panel: KeyPanel?
    private var textView: NSTextView?
    private var scrollView: NSScrollView?
    private var card: NSView?
    private var hintLabel: NSTextField?
    private var quoteLabel: NSTextField?
    private var ctxBoxView: NSView?
    private var onSubmit: ((String) -> Void)?

    private var escMonitor: Any?
    private var clickMonitor: Any?

    private let pw: CGFloat = 440
    private let baseInputH: CGFloat = 24
    private let maxInputH: CGFloat = 120
    private var hasQuote = false
    private var quotedText = ""
    private var hasScreenshot = false
    private var screenshotView: NSImageView?
    private var anchorY: CGFloat = 0
    private var isAIMode = false
    private var topRegionH: CGFloat = 10

    func show(selectedText: String, anchorPoint: NSPoint,
              screenshotPath: String? = nil,
              completion: @escaping (String) -> Void) {
        onSubmit = completion
        close()
        guard let screen = NSScreen.main else { return }

        hasQuote = !selectedText.isEmpty
        quotedText = selectedText
        hasScreenshot = screenshotPath != nil
        let thumbH: CGFloat = hasScreenshot ? 140 : 0
        quoteOffsetFromTop = 36
        topRegionH = hasQuote ? 46 : 10   // topPad(10) + box(26) + gap(10), or just topPad(10)
        let ph: CGFloat = topRegionH + baseInputH + 14 + thumbH
        anchorY = anchorPoint.y

        // Position below the mouse
        var px = anchorPoint.x - pw / 2
        var py = anchorPoint.y - ph - 10
        px = max(12, min(px, screen.frame.width - pw - 12))
        py = max(12, min(py, screen.frame.height - ph - 12))

        let p = KeyPanel(contentRect: NSMakeRect(px, py, pw, ph),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true

        // White card
        let c = NSView(frame: NSMakeRect(0, 0, pw, ph))
        c.wantsLayer = true
        c.layer?.cornerRadius = 12
        c.layer?.backgroundColor = NSColor.white.cgColor
        c.layer?.shadowColor = NSColor.black.cgColor
        c.layer?.shadowOpacity = 0.10
        c.layer?.shadowRadius = 16
        c.layer?.shadowOffset = CGSize(width: 0, height: -3)
        card = c

        var topY = ph

        // Screenshot thumbnail preview
        if hasScreenshot, let path = screenshotPath,
           let img = NSImage(contentsOfFile: path) {
            topY -= (thumbH + 8)
            let imgView = NSImageView(frame: NSMakeRect(12, topY, pw - 24, thumbH))
            imgView.image = img
            imgView.imageScaling = .scaleProportionallyUpOrDown
            imgView.imageAlignment = .alignCenter
            imgView.wantsLayer = true
            imgView.layer?.cornerRadius = 8
            imgView.layer?.masksToBounds = true
            imgView.layer?.backgroundColor = NSColor(white: 0.96, alpha: 1).cgColor
            c.addSubview(imgView)
            screenshotView = imgView
        }

        // Selected text preview
        if hasQuote {
            let txt = Self.truncate(selectedText, max: 55)
            let ctxY = ph - 10 - 26  // 10px from top, 26px box height

            let ctxBox = NSView(frame: NSMakeRect(12, ctxY - 2, pw - 24, 26))
            ctxBox.wantsLayer = true
            ctxBox.layer?.backgroundColor = TC.ctxBg.cgColor
            ctxBox.layer?.cornerRadius = 8
            ctxBox.identifier = NSUserInterfaceItemIdentifier("ctxBox")
            c.addSubview(ctxBox)
            ctxBoxView = ctxBox

            let label = NSTextField(labelWithString: txt)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = TC.muted
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSMakeRect(20, ctxY + 2, pw - 40, 14)
            c.addSubview(label)
            quoteLabel = label
        }

        // NSTextView in NSScrollView for auto-wrapping input
        let inputY: CGFloat = 14
        let sv = NSScrollView(frame: NSMakeRect(10, inputY, pw - 24, baseInputH))
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.borderType = .noBorder
        sv.drawsBackground = false

        let tv = NSTextView(frame: NSMakeRect(0, 0, pw - 24, baseInputH))
        tv.font = NSFont.systemFont(ofSize: 13)
        tv.textColor = TC.sub
        tv.drawsBackground = false
        tv.isRichText = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainerInset = NSSize(width: 2, height: 2)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: pw - 32, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textStorage?.delegate = self
        sv.documentView = tv
        c.addSubview(sv)
        scrollView = sv
        textView = tv

        isAIMode = false

        // Placeholder
        let placeholder = NSTextField(labelWithString: "记个想法… 或 /指令 问AI")
        placeholder.font = NSFont.systemFont(ofSize: 13)
        placeholder.textColor = TC.faint
        placeholder.frame = NSMakeRect(14, inputY + 2, 260, 20)
        placeholder.tag = 999
        c.addSubview(placeholder)

        // Hint
        let hint = NSTextField(labelWithString: "\u{21B5} save \u{00B7} esc")
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = TC.faint
        hint.frame = NSMakeRect(pw - 80, 4, 70, 12)
        hint.alignment = .right
        c.addSubview(hint)
        hintLabel = hint

        p.contentView = c

        // Fade in
        c.alphaValue = 0
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        p.makeFirstResponder(tv)
        panel = p

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            c.animator().alphaValue = 1
        }


        // Keyboard: Esc to close, Enter to submit
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            if ev.keyCode == 53 { self?.close(); return nil }
            if ev.keyCode == 36 && !ev.modifierFlags.contains(.shift) {
                self?.submit(); return nil
            }
            return ev
        }

        // Click outside to close
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    // MARK: Auto-resize as user types

    private var updatingStyle = false

    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard !updatingStyle else { return }
        DispatchQueue.main.async { [weak self] in
            self?.resizeToFit()
        }
    }

    private func resizeToFit() {
        guard let tv = textView, let sv = scrollView,
              let p = panel, let c = card else { return }

        // Hide/show placeholder
        if let ph = c.viewWithTag(999) {
            ph.isHidden = !tv.string.isEmpty
        }

        // Calculate needed height for text
        tv.layoutManager?.ensureLayout(for: tv.textContainer!)
        let usedRect = tv.layoutManager?.usedRect(for: tv.textContainer!) ?? .zero
        let neededH = max(baseInputH, min(ceil(usedRect.height) + 8, maxInputH))

        let inputY: CGFloat = 14
        let thumbH: CGFloat = hasScreenshot ? 148 : 0
        let totalH = topRegionH + neededH + inputY + thumbH

        let dy = totalH - c.frame.height
        if abs(dy) < 1 { return }

        var frame = p.frame
        frame.origin.y -= dy
        frame.size.height += dy
        p.setFrame(frame, display: true)

        c.frame = NSMakeRect(0, 0, pw, totalH)
        sv.frame = NSMakeRect(10, inputY, pw - 24, neededH)
        sv.hasVerticalScroller = neededH >= maxInputH

        repositionTopElements(totalH)
        if let h = hintLabel {
            h.frame = NSMakeRect(pw - 100, inputY + 4, 90, 12)
        }
    }

    private func submit() {
        let typed = textView?.string
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = typed.isEmpty ? quotedText : typed
        guard !text.isEmpty else { close(); return }
        fputs("[TC] submit: \(text)\n", stderr)
        close()
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        onSubmit?(text)
    }

    var isOpen: Bool { panel != nil }

    func close() {
        fputs("[TC] CapturePanel.close()\n", stderr)
        panel?.close(); panel = nil
        screenshotView = nil
        ctxBoxView = nil
        isAIMode = false
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    // Quote offset from top — set once in show(), never changes
    private var quoteOffsetFromTop: CGFloat = 0

    private func repositionTopElements(_ totalH: CGFloat) {
        if hasQuote {
            let ctxY = totalH - quoteOffsetFromTop
            ctxBoxView?.isHidden = false
            ctxBoxView?.frame = NSMakeRect(12, ctxY - 2, pw - 24, 26)
            quoteLabel?.isHidden = false
            quoteLabel?.font = NSFont.systemFont(ofSize: 11)
            quoteLabel?.frame = NSMakeRect(20, ctxY + 2, pw - 40, 14)
        }
    }

    static func truncate(_ s: String, max: Int) -> String {
        let flat = s.replacingOccurrences(of: "\n", with: " ")
        if flat.count <= max { return flat }
        let half = (max - 3) / 2
        return "\(flat.prefix(half))...\(flat.suffix(half))"
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Result Bubble
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ResultItem {
    let id: Int
    let text: String
    let savedTo: String
    let ok: Bool
    let time: String
    let color: NSColor  // matches the bubble color at time of capture
}

/// Draggable thought-bubble icon in screen corner.
/// Hover to see recent captures; click a row to open in Obsidian.
class ResultBubble {
    var dotWin: NSWindow!
    private var popWin: NSWindow!
    private var items: [ResultItem] = []
    private var nextId = 1
    private var hideTimer: Timer?
    private var dragMonitor: Any?

    private let dotSize: CGFloat = 48
    private let popWidth: CGFloat = 320

    init() {
        guard let screen = NSScreen.main else { return }

        // Draggable bubble icon
        let x = screen.frame.width - dotSize - 16
        dotWin = NSWindow(contentRect: NSMakeRect(x, 16, dotSize, dotSize),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        dotWin.level = .floating
        dotWin.isOpaque = false
        dotWin.backgroundColor = .clear
        dotWin.hasShadow = false
        dotWin.isMovableByWindowBackground = false
        dotWin.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let bubble = ThoughtBubbleView(frame: NSMakeRect(0, 0, dotSize, dotSize))
        bubble.onEnter = { [weak self] in self?.showPopover() }
        bubble.onExit  = { [weak self] in self?.scheduleDismiss() }
        bubble.onLeftClick = { [weak self] in self?.togglePopover() }
        bubble.onSettings = { [weak self] in self?.openSettingsWindow() }
        dotWin.contentView = bubble

        // Gentle floating animation
        startFloating()

        // Popover (hidden until hover)
        popWin = NSWindow(contentRect: NSMakeRect(0, 0, popWidth, 100),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        popWin.level = .floating
        popWin.isOpaque = false
        popWin.backgroundColor = .clear
        popWin.hasShadow = true
        popWin.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let container = TrackView(frame: NSMakeRect(0, 0, popWidth, 100))
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.backgroundColor = NSColor.white.cgColor
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.08
        container.layer?.shadowRadius = 14
        container.layer?.shadowOffset = CGSize(width: 0, height: -2)
        container.onEnter = { [weak self] in self?.cancelDismiss() }
        container.onExit  = { [weak self] in self?.scheduleDismiss() }
        popWin.contentView = container

        // Hide popover when user starts dragging the dot
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) {
            [weak self] event in
            if let self = self, self.popWin.isVisible {
                self.popWin.orderOut(nil)
                self.cancelDismiss()
            }
            return event
        }

        dotWin.orderFront(nil)
    }

    // MARK: Animations

    /// Gentle bobbing — animates the layer, not the window, so dragging works.
    func startFloating() {
        guard let layer = dotWin.contentView?.layer else { return }
        let float = CABasicAnimation(keyPath: "transform.translation.y")
        float.fromValue = -2.5
        float.toValue = 2.5
        float.duration = 2.4
        float.autoreverses = true
        float.repeatCount = .infinity
        float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(float, forKey: "float")
    }

    /// Visual + audio feedback when a thought is saved.
    func playSuccessFeedback() {
        guard let bubble = dotWin.contentView as? ThoughtBubbleView else { return }

        // Orb intensifies + shifts color
        bubble.intensify()

        // Scale bounce on the whole view
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.25, 0.93, 1.05, 1.0]
        bounce.keyTimes = [0, 0.15, 0.45, 0.7, 1.0]
        bounce.duration = 0.45
        bubble.layer?.add(bounce, forKey: "bounce")

        NSSound(named: "Bottle")?.play()
    }

    // MARK: Show / Hide

    private func showPopover() {
        cancelDismiss()
        rebuildPopover()
        positionPopover()

        // Add as child window so it follows when dot is dragged
        if !(dotWin.childWindows?.contains(popWin) ?? false) {
            dotWin.addChildWindow(popWin, ordered: .above)
        }
        popWin.orderFront(nil)
    }

    /// Position popover to the left or right of dot, whichever fits on screen.
    private func positionPopover() {
        let dot = dotWin.frame
        let pop = popWin.frame
        let screen = dotWin.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let gap: CGFloat = 6

        // Try left first
        var x = dot.minX - pop.width - gap
        if x < screen.visibleFrame.minX {
            // Doesn't fit left, put it right
            x = dot.maxX + gap
        }
        // Vertical: align bottom edges, clamp to screen
        var y = dot.minY
        y = max(screen.visibleFrame.minY, min(y, screen.visibleFrame.maxY - pop.height))

        popWin.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func scheduleDismiss() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.dotWin.removeChildWindow(self.popWin)
            self.popWin.orderOut(nil)
        }
    }

    private func cancelDismiss() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func togglePopover() {
        if popWin.isVisible {
            dotWin.removeChildWindow(popWin)
            popWin.orderOut(nil)
        } else {
            showPopover()
        }
    }

    // MARK: Settings Window

    private var settingsWin: NSWindow?
    // Keep action targets alive
    private var settingsTargets: [AnyObject] = []

    func openSettingsWindow() {
        if let existing = settingsWin, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        settingsTargets.removeAll()

        let W: CGFloat = 380, H: CGFloat = 240
        let win = NSWindow(contentRect: NSMakeRect(0, 0, W, H),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = "ThoughtCapture Settings"
        win.center()
        win.isReleasedWhenClosed = false

        let root = NSView(frame: NSMakeRect(0, 0, W, H))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let px: CGFloat = 24
        let fw: CGFloat = W - px * 2
        var y: CGFloat = H - 24

        // ── Helpers ──
        func label(_ text: String, at yy: inout CGFloat, size: CGFloat = 11, color: NSColor = .secondaryLabelColor) {
            let l = NSTextField(labelWithString: text)
            l.font = .systemFont(ofSize: size)
            l.textColor = color
            l.frame = NSMakeRect(px, yy - 14, fw, 14)
            root.addSubview(l)
            yy -= 18
        }

        func sep(at yy: inout CGFloat) {
            let s = NSView(frame: NSMakeRect(px, yy - 8, fw, 1))
            s.wantsLayer = true
            s.layer?.backgroundColor = NSColor.separatorColor.cgColor
            root.addSubview(s)
            yy -= 20
        }

        // ━━━  Storage  ━━━
        label("SAVE TO", at: &y, size: 11, color: .tertiaryLabelColor)

        let storageSeg = NSSegmentedControl(labels: ["Obsidian Vault", "Apple Notes"], trackingMode: .selectOne, target: nil, action: nil)
        storageSeg.selectedSegment = 0
        storageSeg.frame = NSMakeRect(px, y - 24, fw, 24)
        storageSeg.identifier = NSUserInterfaceItemIdentifier("storage")
        root.addSubview(storageSeg)
        y -= 36

        // Vault folder
        let vaultRow = NSView(frame: NSMakeRect(px, y - 26, fw, 26))
        vaultRow.identifier = NSUserInterfaceItemIdentifier("vaultRow")
        root.addSubview(vaultRow)

        let vpField = NSTextField(frame: NSMakeRect(0, 2, fw - 66, 22))
        vpField.placeholderString = "~/obsidian"
        vpField.font = .systemFont(ofSize: 12)
        vpField.identifier = NSUserInterfaceItemIdentifier("vaultPath")
        vpField.bezelStyle = .roundedBezel
        vaultRow.addSubview(vpField)

        let browseBtn = NSButton(title: "Choose…", target: nil, action: nil)
        browseBtn.bezelStyle = .rounded
        browseBtn.controlSize = .small
        browseBtn.font = .systemFont(ofSize: 11)
        browseBtn.frame = NSMakeRect(fw - 62, 1, 62, 22)
        vaultRow.addSubview(browseBtn)
        y -= 36

        class BrowseHandler: NSObject {
            weak var pathField: NSTextField?
            @objc func pick(_ sender: Any) {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.prompt = "Choose Vault"
                if panel.runModal() == .OK, let url = panel.url {
                    pathField?.stringValue = url.path
                }
            }
        }
        let browseHandler = BrowseHandler()
        browseHandler.pathField = vpField
        browseBtn.target = browseHandler
        browseBtn.action = #selector(BrowseHandler.pick(_:))
        settingsTargets.append(browseHandler)

        class StorageToggle: NSObject {
            weak var vaultRow: NSView?
            @objc func changed(_ sender: NSSegmentedControl) {
                vaultRow?.isHidden = sender.selectedSegment != 0
                if sender.selectedSegment == 1 {
                    // Trigger Automation permission for Notes on first switch
                    DispatchQueue.global().async {
                        let proc = Process()
                        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                        proc.arguments = ["-e", "tell application \"Notes\" to get name of first note of default account"]
                        try? proc.run()
                        proc.waitUntilExit()
                    }
                }
            }
        }
        let storageToggle = StorageToggle()
        storageToggle.vaultRow = vaultRow
        storageSeg.target = storageToggle
        storageSeg.action = #selector(StorageToggle.changed(_:))
        settingsTargets.append(storageToggle)

        // ━━━  Bottom  ━━━
        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .systemGreen
        statusLabel.frame = NSMakeRect(px, 17, 200, 14)
        statusLabel.identifier = NSUserInterfaceItemIdentifier("status")
        root.addSubview(statusLabel)

        let saveBtn = NSButton(title: "Save", target: nil, action: nil)
        saveBtn.bezelStyle = .rounded
        saveBtn.frame = NSMakeRect(W - px - 70, 12, 70, 26)
        saveBtn.keyEquivalent = "\r"
        root.addSubview(saveBtn)

        win.contentView = root

        // ── Wire up actions ──

        // Save
        class SaveHandler: NSObject {
            weak var root: NSView?
            @objc func save(_ sender: Any) {
                guard let root = root else { return }

                func textField(in view: NSView, id: String) -> NSTextField? {
                    for sub in view.subviews {
                        if let tf = sub as? NSTextField, tf.identifier?.rawValue == id { return tf }
                        if let found = textField(in: sub, id: id) { return found }
                    }
                    return nil
                }
                func segValue(in view: NSView, id: String) -> Int {
                    for sub in view.subviews {
                        if let seg = sub as? NSSegmentedControl, seg.identifier?.rawValue == id { return seg.selectedSegment }
                        let found = segValue(in: sub, id: id)
                        if found >= 0 { return found }
                    }
                    return -1
                }

                let isObsidian = segValue(in: root, id: "storage") == 0
                let vaultPath = textField(in: root, id: "vaultPath")?.stringValue ?? ""
                let vaultName = URL(fileURLWithPath: vaultPath).lastPathComponent
                let backend = isObsidian ? "obsidian" : "notes"

                LocalStorage.shared.vaultPath = vaultPath
                LocalStorage.shared.backend = backend
                if !vaultName.isEmpty {
                    ResultBubble.vaultName = vaultName
                    UserDefaults.standard.set(vaultName, forKey: "vaultName")
                }

                let status = textField(in: root, id: "status")
                status?.textColor = .systemGreen
                status?.stringValue = "✓ Saved"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    status?.stringValue = ""
                }
            }
        }
        let saveHandler = SaveHandler()
        saveHandler.root = root
        saveBtn.target = saveHandler
        saveBtn.action = #selector(SaveHandler.save(_:))
        settingsTargets.append(saveHandler)

        // ── Load current values ──
        loadSettings(root: root, storageSeg: storageSeg, vaultRow: vaultRow)

        settingsWin = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadSettings(root: NSView, storageSeg: NSSegmentedControl, vaultRow: NSView) {
        func textField(in view: NSView, id: String) -> NSTextField? {
            for sub in view.subviews {
                if let tf = sub as? NSTextField, tf.identifier?.rawValue == id { return tf }
                if let found = textField(in: sub, id: id) { return found }
            }
            return nil
        }
        let storage = LocalStorage.shared.backend
        storageSeg.selectedSegment = storage == "notes" ? 1 : 0
        vaultRow.isHidden = storage == "notes"
        let savedVaultPath = LocalStorage.shared.vaultPath
        if !savedVaultPath.isEmpty {
            textField(in: root, id: "vaultPath")?.stringValue = savedVaultPath
        }
    }

    // MARK: Data

    func addItem(text: String, savedTo: String, ok: Bool) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        // Animate first — color shifts to the NEW color for this thought
        if ok { playSuccessFeedback() }

        // Now capture the NEW color (post-intensify) as this thought's identity
        let bubbleColor: NSColor
        if let bubble = dotWin.contentView as? ThoughtBubbleView {
            bubbleColor = bubble.currentColor
        } else {
            bubbleColor = TC.green
        }

        let item = ResultItem(id: nextId, text: text, savedTo: savedTo,
                              ok: ok, time: formatter.string(from: Date()),
                              color: bubbleColor)
        nextId += 1
        items.insert(item, at: 0)
        if items.count > 20 { items = Array(items.prefix(20)) }
        dotWin.orderFront(nil)
        if popWin.isVisible { rebuildPopover() }
    }

    // MARK: Popover Layout

    private func rebuildPopover() {
        guard let container = popWin.contentView as? TrackView else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        let rowH: CGFloat = 32
        let pad: CGFloat = 8

        let visibleThoughts = items
        let thoughtCount = min(visibleThoughts.count, 8)

        // Empty state
        if thoughtCount == 0 {
            let emptyH: CGFloat = 64
            container.frame = NSMakeRect(0, 0, popWidth, emptyH)
            let hint = NSTextField(labelWithString: "Press ⌥T to capture a thought")
            hint.font = rounded(size: 12)
            hint.textColor = TC.muted
            hint.alignment = .center
            hint.frame = NSMakeRect(10, (emptyH - 16) / 2, popWidth - 20, 16)
            container.addSubview(hint)
            popWin.setContentSize(NSSize(width: popWidth, height: emptyH))
            return
        }

        // Calculate total height
        var totalH = pad
        totalH += 18
        totalH += CGFloat(thoughtCount) * rowH
        totalH += 8

        container.frame = NSMakeRect(0, 0, popWidth, totalH)
        var y = totalH - pad

        // ── Thoughts Section ──
        if thoughtCount > 0 {
            y -= 16
            let header = NSTextField(labelWithString: "THOUGHTS")
            header.font = rounded(size: 9, weight: .medium)
            header.textColor = TC.muted
            header.frame = NSMakeRect(10, y + 1, popWidth - 20, 13)
            container.addSubview(header)

            for i in 0..<thoughtCount {
                let item = visibleThoughts[i]
                y -= rowH

                let row = ClickableRow(frame: NSMakeRect(4, y, popWidth - 8, rowH))
                let path = item.savedTo
                let text = item.text
                row.onClick = { ResultBubble.openSavedThought(path: path, searchText: text) }
                row.wantsLayer = true
                row.layer?.cornerRadius = 6

                // Color dot
                let dot = NSView(frame: NSMakeRect(8, (rowH - 6) / 2, 6, 6))
                dot.wantsLayer = true
                dot.layer?.cornerRadius = 3
                dot.layer?.backgroundColor = (item.ok ? item.color : TC.red).cgColor
                row.addSubview(dot)

                // Text
                let label = NSTextField(labelWithString: item.text)
                label.font = rounded(size: 12)
                label.textColor = TC.text
                label.lineBreakMode = .byTruncatingTail
                label.frame = NSMakeRect(22, (rowH - 14) / 2, popWidth - 76, 14)
                row.addSubview(label)

                // Time
                let time = NSTextField(labelWithString: item.time)
                time.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                time.textColor = TC.faint
                time.alignment = .right
                time.frame = NSMakeRect(popWidth - 54, (rowH - 12) / 2, 36, 12)
                row.addSubview(time)

                container.addSubview(row)
                if i < thoughtCount - 1 {
                    let sep = NSView(frame: NSMakeRect(22, y, popWidth - 44, 0.5))
                    sep.wantsLayer = true
                    sep.layer?.backgroundColor = NSColor(white: 0, alpha: 0.04).cgColor
                    container.addSubview(sep)
                }
            }
        }

        popWin.setContentSize(NSSize(width: popWidth, height: totalH))
        if popWin.isVisible { positionPopover() }
    }

    // MARK: Font helper
    private func rounded(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let sys = NSFont.systemFont(ofSize: size, weight: weight)
        if let desc = sys.fontDescriptor.withDesign(.rounded) {
            return NSFont(descriptor: desc, size: size) ?? sys
        }
        return sys
    }

    // MARK: Open in Obsidian

    static var vaultName: String = {
        UserDefaults.standard.string(forKey: "vaultName") ?? "obsidian"
    }()

    static var storageBackend: String = {
        UserDefaults.standard.string(forKey: "storageBackend") ?? "obsidian"
    }()

    static func fetchConfig(sync: Bool = false) {
        if let name = UserDefaults.standard.string(forKey: "vaultName"), !name.isEmpty {
            vaultName = name
        }
        if let backend = UserDefaults.standard.string(forKey: "storageBackend"), !backend.isEmpty {
            storageBackend = backend
        }
    }

    /// Open a saved thought — dispatches to Obsidian or Apple Notes based on backend.
    static func openSavedThought(path: String, searchText: String = "") {
        if storageBackend == "notes" {
            openInNotes(searchText: searchText)
        } else {
            openInObsidian(path: path, searchText: searchText)
        }
    }

    static func openInObsidian(path: String, searchText: String = "") {
        guard !path.isEmpty else { return }
        let file = path.components(separatedBy: " + ").first ?? path
        let encoded = file.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? file
        if let url = URL(string: "obsidian://open?vault=\(vaultName)&file=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
        if !searchText.isEmpty {
            let query = String(searchText.prefix(30))
            let searchQuery = "path:\"\(file)\" \"\(query)\""
            if let sq = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let searchUrl = URL(string: "obsidian://search?vault=\(vaultName)&query=\(sq)") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSWorkspace.shared.open(searchUrl)
                }
            }
        }
    }

    static func openInNotes(searchText: String = "") {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: Date())
        let noteTitle = "Thoughts — \(dateStr)"
        let script = """
        tell application "Notes"
            activate
            set noteFound to false
            repeat with n in notes of default account
                if name of n is "\(noteTitle)" then
                    show n
                    set noteFound to true
                    exit repeat
                end if
            end repeat
        end tell
        """
        DispatchQueue.global().async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            try? proc.run()
        }
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - UI Components
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Clickable row with hover highlight and pointer cursor.
class ClickableRow: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .cursorUpdate],
            owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.03).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }
}

/// View with mouse enter/exit callbacks.
class TrackView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

/// Simple gradient circle with soft breathing pulse.
class ThoughtBubbleView: TrackView {
    var onLeftClick: (() -> Void)?
    var onSettings: (() -> Void)?
    private var dragOrigin: NSPoint?
    private var isDragging = false

    override func mouseDown(with event: NSEvent) {
        dragOrigin = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }
        let loc = event.locationInWindow
        let dx = abs(loc.x - origin.x), dy = abs(loc.y - origin.y)
        if dx > 3 || dy > 3 { isDragging = true }
        if isDragging, let win = window {
            var frame = win.frame
            frame.origin.x += event.deltaX
            frame.origin.y -= event.deltaY
            win.setFrameOrigin(frame.origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging { onLeftClick?() }
        dragOrigin = nil
        isDragging = false
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…",
                                       action: #selector(openSettings),
                                       keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ThoughtCapture",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: ""))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func openSettings() { onSettings?() }

    private var circle: CAGradientLayer!
    var colorIdx = 0
    private var colorIndex: Int {
        get { colorIdx }
        set { colorIdx = newValue }
    }

    // (top, bottom) linear gradient pairs
    private let palette: [(NSColor, NSColor)] = [
        (NSColor(red: 0.96, green: 0.65, blue: 0.45, alpha: 1),   // peach
         NSColor(red: 0.90, green: 0.42, blue: 0.50, alpha: 1)),   // coral
        (NSColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1),   // light blue
         NSColor(red: 0.38, green: 0.50, blue: 0.85, alpha: 1)),   // blue
        (NSColor(red: 0.85, green: 0.70, blue: 0.95, alpha: 1),   // lilac
         NSColor(red: 0.62, green: 0.45, blue: 0.82, alpha: 1)),   // purple
        (NSColor(red: 0.60, green: 0.90, blue: 0.75, alpha: 1),   // mint
         NSColor(red: 0.35, green: 0.70, blue: 0.62, alpha: 1)),   // green
        (NSColor(red: 0.95, green: 0.80, blue: 0.45, alpha: 1),   // golden
         NSColor(red: 0.88, green: 0.58, blue: 0.30, alpha: 1)),   // amber
        (NSColor(red: 0.70, green: 0.85, blue: 0.55, alpha: 1),   // lime
         NSColor(red: 0.48, green: 0.72, blue: 0.40, alpha: 1)),   // olive
        (NSColor(red: 0.95, green: 0.55, blue: 0.65, alpha: 1),   // pink
         NSColor(red: 0.82, green: 0.35, blue: 0.48, alpha: 1)),   // raspberry
        (NSColor(red: 0.50, green: 0.75, blue: 0.88, alpha: 1),   // sky
         NSColor(red: 0.32, green: 0.58, blue: 0.75, alpha: 1)),   // steel
    ]

    /// The current dominant color (bottom gradient), exposed for popover dots.
    var currentColor: NSColor { palette[colorIndex].1 }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false

        let s: CGFloat = 28
        let cx = frame.width / 2
        let cy = frame.height / 2
        let (top, bot) = palette[0]

        circle = CAGradientLayer()
        circle.frame = CGRect(x: cx - s/2, y: cy - s/2, width: s, height: s)
        circle.cornerRadius = s / 2
        circle.colors = [top.cgColor, bot.cgColor]
        circle.startPoint = CGPoint(x: 0.5, y: 1.0)
        circle.endPoint = CGPoint(x: 0.5, y: 0.0)
        layer?.addSublayer(circle)

        // Gentle breathing
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.95; pulse.toValue = 1.05
        pulse.duration = 3.0; pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        circle.add(pulse, forKey: "pulse")
    }
    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { false }

    func intensify() {
        colorIndex = (colorIndex + 1) % palette.count
        let (top, bot) = palette[colorIndex]

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.6)
        circle.colors = [top.cgColor, bot.cgColor]
        CATransaction.commit()

        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 1.25, 0.95, 1.0]
        pop.keyTimes = [0, 0.15, 0.5, 1.0]
        pop.duration = 0.4
        circle.add(pop, forKey: "pop")
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Selection Toolbar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Minimal floating toolbar that appears when text is selected.
/// Two actions: pin (save directly) and expand (open capture panel).
class SelectionToolbar {
    private var window: NSWindow?
    private var mouseDownPos: NSPoint?
    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var hideTimer: Timer?

    var onPin: ((String) -> Void)?      // direct save
    var onExpand: ((String, NSPoint) -> Void)?  // open capture panel

    private let toolbarW: CGFloat = 68
    private let toolbarH: CGFloat = 28

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

    private func checkAndShow(at pos: NSPoint) {
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
        guard let screen = NSScreen.main else { return }

        // Position: slightly below and right of mouse
        var x = mousePos.x + 8
        var y = mousePos.y - toolbarH - 8

        // Keep on screen
        if x + toolbarW > screen.frame.maxX - 10 { x = mousePos.x - toolbarW - 8 }
        if y < screen.frame.minY + 10 { y = mousePos.y + 8 }

        let win = NSWindow(contentRect: NSMakeRect(x, y, toolbarW, toolbarH),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false

        let container = NSView(frame: NSMakeRect(0, 0, toolbarW, toolbarH))
        container.wantsLayer = true
        container.layer?.cornerRadius = toolbarH / 2
        container.layer?.backgroundColor = NSColor(white: 1, alpha: 0.95).cgColor
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.12
        container.layer?.shadowRadius = 10
        container.layer?.shadowOffset = CGSize(width: 0, height: -2)
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor(white: 0, alpha: 0.06).cgColor

        // Expand button (colored dot — same palette as bubble)
        let dotBtn = ClickableRow(frame: NSMakeRect(4, 4, toolbarH - 8, toolbarH - 8))
        let dotLayer = CAGradientLayer()
        let dotSize = toolbarH - 8
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
        dotBtn.layer?.addSublayer(dotLayer)
        let text = selectedText
        let pos = mousePos
        dotBtn.onClick = { [weak self] in
            self?.dismiss()
            self?.onExpand?(text, pos)
        }
        container.addSubview(dotBtn)

        // Pin button
        let pinBtn = ClickableRow(frame: NSMakeRect(toolbarW / 2 + 2, 0, toolbarW / 2 - 4, toolbarH))
        let pinLabel = NSTextField(labelWithString: "📌")
        pinLabel.font = NSFont.systemFont(ofSize: 13)
        pinLabel.frame = NSMakeRect((pinBtn.frame.width - 20) / 2, (toolbarH - 18) / 2, 20, 18)
        pinBtn.addSubview(pinLabel)
        pinBtn.onClick = { [weak self] in
            self?.dismiss()
            self?.onPin?(text)
        }
        container.addSubview(pinBtn)

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


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Entry Point
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Single-instance guard — exit if another ThoughtCapture is already running
let myPID = ProcessInfo.processInfo.processIdentifier
let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.thoughtcapture.app")
if running.contains(where: { $0.processIdentifier != myPID }) {
    fputs("[TC] Another instance is already running. Exiting.\n", stderr)
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Add standard Edit menu so Cmd+V / Cmd+C / Cmd+A work in text fields (e.g. Settings)
let mainMenu = NSMenu()
let editMenuItem = NSMenuItem()
editMenuItem.submenu = {
    let m = NSMenu(title: "Edit")
    m.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    m.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    m.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    m.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    return m
}()
mainMenu.addItem(editMenuItem)
app.mainMenu = mainMenu

let delegate = AppDelegate()
app.delegate = delegate
app.run()
