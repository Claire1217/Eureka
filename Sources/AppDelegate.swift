import Cocoa
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var hotKeyScreenshotRef: EventHotKeyRef?
    var capturePanel: CapturePanel?
    var resultBubble: ResultBubble?
    var selectionToolbar: SelectionToolbar?
    var prevAppBundleId: String?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        fputs("[Eureka] AX trusted on launch: \(trusted)\n", stderr)

        setupMenubar()
        registerHotkey()
        resultBubble = ResultBubble()
        ResultBubble.fetchConfig(sync: true)
        setupSelectionToolbar()

        if !trusted {
            showAccessibilityGuide()
        } else if LocalStorage.shared.vaultPath.isEmpty && LocalStorage.shared.backend == "obsidian" {
            showFirstLaunchSetup()
        }
    }

    func showAccessibilityGuide() {
        let alert = NSAlert()
        alert.messageText = "Eureka needs Accessibility permission"
        alert.informativeText = "To capture thoughts with a global hotkey, Eureka needs Accessibility access.\n\nClick \"Open Settings\" to go there now, then enable Eureka in the list."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if LocalStorage.shared.vaultPath.isEmpty && LocalStorage.shared.backend == "obsidian" {
                self?.showFirstLaunchSetup()
            }
        }
    }

    func showFirstLaunchSetup() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Eureka"
        alert.informativeText = "Press \(captureHotkeyLabel) anywhere to capture a thought.\n\nFirst, choose where to save your thoughts:"
        alert.addButton(withTitle: "Choose Obsidian Vault…")
        alert.addButton(withTitle: "Use Apple Notes")
        alert.alertStyle = .informational

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = false
            panel.prompt = "Select Vault"
            panel.message = "Select your Obsidian vault root folder.\nThoughts will be saved to a \"Eureka\" subfolder inside it."
            if panel.runModal() == .OK, let url = panel.url {
                let eurekaDir = url.appendingPathComponent("Eureka").path
                try? FileManager.default.createDirectory(atPath: eurekaDir, withIntermediateDirectories: true)
                LocalStorage.shared.vaultPath = eurekaDir
                LocalStorage.shared.backend = "obsidian"
                // Styled cards from the first thought on, not only after a Settings save
                LocalStorage.shared.installObsidianSnippet()

                let name = url.lastPathComponent
                ResultBubble.vaultName = name
                UserDefaults.standard.set(name, forKey: "vaultName")

                let done = NSAlert()
                done.messageText = "You're all set!"
                done.informativeText = "Thoughts will be saved to:\n\(eurekaDir)\n\nTo change this later, click the E! menu bar icon → Settings."
                done.addButton(withTitle: "OK")
                done.alertStyle = .informational
                done.runModal()
            }
        } else {
            LocalStorage.shared.backend = "notes"
        }
    }

    func setupSelectionToolbar() {
        selectionToolbar = SelectionToolbar()

        // Click the dot: open capture panel with selected text
        selectionToolbar?.onExpand = { [weak self] text, pos in
            guard let self = self else { return }
            self.prevAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
            let browserURL = self.getBrowserURL(appName: appName)
            if self.capturePanel == nil { self.capturePanel = CapturePanel() }
            self.capturePanel?.show(selectedText: text, anchorPoint: pos) { [weak self] thought in
                self?.saveThought(thought: thought, selectedText: text,
                                  appName: appName, browserURL: browserURL)
            }
        }

        selectionToolbar?.startMonitoring()
    }

    // MARK: Menubar

    func setupMenubar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "E!"

        rebuildMenu()
    }

    /// Rebuilt after Settings are saved so the hotkey labels stay current.
    func rebuildMenu() {
        let menu = NSMenu()
        let captureItem = NSMenuItem(title: "Capture Thought (\(captureHotkeyLabel))",
                                     action: #selector(triggerCapture), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)
        let screenshotItem = NSMenuItem(title: "Screenshot + Comment (\(screenshotHotkeyLabel))",
                                        action: #selector(triggerScreenshot), keyEquivalent: "")
        screenshotItem.target = self
        menu.addItem(screenshotItem)
        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Eureka", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func openSettings() {
        resultBubble?.openSettingsWindow()
    }

    // MARK: Global Hotkey (Carbon)

    private var eventHandlerInstalled = false
    /// True when the last registerHotkey() could not claim one of the combinations.
    private(set) var hotkeyRegistrationFailed = false

    func registerHotkey() {
        // Unregister old hotkeys if re-registering
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = hotKeyScreenshotRef { UnregisterEventHotKey(ref); hotKeyScreenshotRef = nil }

        if !eventHandlerInstalled {
            var eventType = EventTypeSpec()
            eventType.eventClass = OSType(kEventClassKeyboard)
            eventType.eventKind = UInt32(kEventHotKeyPressed)
            InstallEventHandler(
                GetApplicationEventTarget(), hotKeyHandler, 1, &eventType,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), nil)
            eventHandlerInstalled = true
        }

        let captureKey = UserDefaults.standard.object(forKey: "hotkeyCapture") as? UInt32 ?? HOTKEY_KEYCODE
        let captureMods = UserDefaults.standard.object(forKey: "hotkeyCaptureMods") as? UInt32 ?? HOTKEY_MODIFIERS
        let screenshotKey = UserDefaults.standard.object(forKey: "hotkeyScreenshot") as? UInt32 ?? HOTKEY_SCREENSHOT
        let screenshotMods = UserDefaults.standard.object(forKey: "hotkeyScreenshotMods") as? UInt32 ?? HOTKEY_MODIFIERS

        var hotKeyID1 = EventHotKeyID()
        hotKeyID1.signature = OSType(0x54435F48)
        hotKeyID1.id = 1
        let s1 = RegisterEventHotKey(captureKey, captureMods, hotKeyID1,
                                     GetApplicationEventTarget(), 0, &hotKeyRef)

        var hotKeyID2 = EventHotKeyID()
        hotKeyID2.signature = OSType(0x54435F48)
        hotKeyID2.id = 2
        let s2 = RegisterEventHotKey(screenshotKey, screenshotMods, hotKeyID2,
                                     GetApplicationEventTarget(), 0, &hotKeyScreenshotRef)
        // e.g. eventHotKeyExistsErr when another app already owns the combination
        hotkeyRegistrationFailed = (s1 != noErr || s2 != noErr)
        if s1 != noErr { fputs("[Eureka] Failed to register capture hotkey (OSStatus \(s1))\n", stderr) }
        if s2 != noErr { fputs("[Eureka] Failed to register screenshot hotkey (OSStatus \(s2))\n", stderr) }
    }

    // MARK: Capture Flow

    @objc func triggerCapture() {
        let prevApp = NSWorkspace.shared.frontmostApplication
        prevAppBundleId = prevApp?.bundleIdentifier

        let mousePos = NSEvent.mouseLocation
        let selectedText = getSelectedText()
        let appName = prevApp?.localizedName ?? "Unknown"
        let browserURL = getBrowserURL(appName: appName)

        if capturePanel == nil { capturePanel = CapturePanel() }
        capturePanel?.show(selectedText: selectedText, anchorPoint: mousePos) { [weak self] thought in
            self?.saveThought(thought: thought, selectedText: selectedText,
                              appName: appName, browserURL: browserURL)
        }
    }

    // MARK: Screenshot Capture Flow (⌥R)

    @objc func triggerScreenshot() {
        let prevApp = NSWorkspace.shared.frontmostApplication
        let appName = prevApp?.localizedName ?? "Unknown"
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
                    self?.saveThought(thought: thought, selectedText: "",
                                      appName: appName, browserURL: browserURL,
                                      screenshotPath: tmpPath)
                }
            }
        }
    }

    // MARK: Selected Text (Accessibility API + Cmd+C fallback)

    var lastSelectionEditable: Bool = false

    func getSelectedText() -> String {
        func dbg(_ msg: String) { fputs("[Eureka] \(msg)\n", stderr) }

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
            // Snapshot the clipboard so the synthetic Cmd+C doesn't clobber it
            let savedItems: [NSPasteboardItem] = (pb.pasteboardItems ?? []).map { item in
                let copy = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) { copy.setData(data, forType: type) }
                }
                return copy
            }
            let src = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
            down?.flags = .maskCommand; up?.flags = .maskCommand
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
            // Poll instead of a fixed sleep — usually done in ~40ms
            var waited: UInt32 = 0
            while pb.changeCount == oldCount && waited < 200_000 {
                usleep(20_000); waited += 20_000
            }

            if pb.changeCount != oldCount {
                let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                pb.clearContents()
                pb.writeObjects(savedItems)
                if !text.isEmpty {
                    dbg("Got context from clipboard (\(text.count) chars)")
                    return text
                }
            }
        }

        // No fallback to the existing clipboard: whatever the user copied earlier
        // (passwords, addresses…) is unrelated to this thought and must not be saved.
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
            fputs("[Eureka] osascript timed out\n", stderr)
            return ""
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: Save Thought

    func saveThought(thought: String, selectedText: String,
                     appName: String, browserURL: String,
                     screenshotPath: String? = nil) {
        let cleanThought = thought

        // Any "/" prefix → DeepSeek quick Q&A (streaming in panel)
        if cleanThought.hasPrefix("/") || cleanThought.hasPrefix("／") {
            let stripped = String(cleanThought.drop(while: { $0 == "/" || $0 == "／" }))
            // Also strip an explicit "ask " / "问 " command word — only when it is
            // followed by whitespace, so "/asking price" and "/问题是…" stay intact
            var question = stripped.trimmingCharacters(in: .whitespaces)
            for p in ["问", "ask"] {
                let rest = question.dropFirst(p.count)
                if question.lowercased().hasPrefix(p), let next = rest.first, next.isWhitespace {
                    question = String(rest)
                    break
                }
            }
            question = question.trimmingCharacters(in: .whitespaces)
            if question.isEmpty || ["ask", "问"].contains(question.lowercased()) { return }
            capturePanel?.showStreamingAnswer()
            askDeepSeekStreaming(question: question, context: selectedText)
            return
        }
        if cleanThought.isEmpty && selectedText.isEmpty && screenshotPath == nil { return }

        // Enter on an empty input submits the quote itself as the thought —
        // don't write the same text again as its own context.
        let quote = (selectedText == cleanThought) ? "" : selectedText

        capturePanel?.close()

        // Off the main thread: the Apple Notes backend shells out to osascript and
        // can take seconds. The queue is serial, so entries keep their order.
        saveQueue.async { [weak self] in
            let result = LocalStorage.shared.save(
                thought: cleanThought, selectedText: quote,
                appName: appName, browserURL: browserURL,
                screenshotPath: screenshotPath)
            DispatchQueue.main.async {
                // A screenshot may be saved without a comment
                let label = cleanThought.isEmpty ? "Screenshot" : cleanThought
                self?.resultBubble?.addItem(text: label, savedTo: result.savedTo, ok: result.ok)
            }
        }
    }

    private let saveQueue = DispatchQueue(label: "com.eureka.app.save", qos: .userInitiated)

    /// Saves are asynchronous — let an in-flight one finish before quitting.
    func applicationWillTerminate(_ notification: Notification) {
        saveQueue.sync {}
    }

    private var streamSession: URLSession?
    private var streamDelegate: StreamingDelegate?

    func askDeepSeekStreaming(question: String, context: String) {
        let storage = LocalStorage.shared
        let apiKey = storage.llmApiKey
        let apiBase = storage.llmApiBase
        let model = storage.llmModel

        guard !apiKey.isEmpty else {
            fputs("[Eureka] DeepSeek API key not set\n", stderr)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.capturePanel?.finishStreamWithMessage("API key 未设置\n\n点击菜单栏 E! → Settings → 填入 DeepSeek API key\n获取: platform.deepseek.com")
            }
            return
        }

        var messages: [[String: String]] = [
            ["role": "system", "content": storage.llmSystemPrompt]
        ]
        if !context.isEmpty {
            messages.append(["role": "user", "content": "Context:\n\(context)\n\nQuestion: \(question)"])
        } else {
            messages.append(["role": "user", "content": question])
        }

        let body: [String: Any] = ["model": model, "messages": messages,
                                    "max_tokens": 512, "temperature": 0.7, "stream": true]

        guard let url = URL(string: apiBase),
              let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = jsonData
        req.timeoutInterval = 60

        let del = StreamingDelegate(panel: capturePanel, bubble: resultBubble, question: question)
        // Cancel any in-flight request; the session retains its delegate until invalidated
        streamSession?.invalidateAndCancel()
        streamDelegate = del
        let session = URLSession(configuration: .default, delegate: del, delegateQueue: nil)
        streamSession = session
        session.dataTask(with: req).resume()
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

// MARK: - SSE Streaming Delegate

class StreamingDelegate: NSObject, URLSessionDataDelegate {
    weak var panel: CapturePanel?
    weak var bubble: ResultBubble?
    let question: String
    private var buffer = ""
    private var fullAnswer = ""
    private var statusCode = 0
    private var errorBody = ""
    private var finished = false

    init(panel: CapturePanel?, bubble: ResultBubble?, question: String) {
        self.panel = panel
        self.bubble = bubble
        self.question = question
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        // Non-200 responses are plain JSON errors, not SSE — collect for didComplete
        if statusCode != 200 {
            errorBody += chunk
            return
        }
        buffer += chunk

        while let lineEnd = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex..<lineEnd])
            buffer = String(buffer[buffer.index(after: lineEnd)...])

            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.finished else { return }
                    self.finished = true
                    self.panel?.finishStream()
                    fputs("[Eureka] DeepSeek stream done: \(self.fullAnswer.prefix(80))...\n", stderr)
                }
                return
            }

            guard let jsonData = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }

            fullAnswer += content
            DispatchQueue.main.async { [weak self] in
                self?.panel?.appendStreamChunk(content)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        defer { session.finishTasksAndInvalidate() }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.finished else { return }
            self.finished = true
            if let err = error {
                if (err as NSError).code == NSURLErrorCancelled { return }
                fputs("[Eureka] DeepSeek stream error: \(err.localizedDescription)\n", stderr)
                self.panel?.appendStreamChunk("\n⚠️ \(err.localizedDescription)")
                self.panel?.finishStream()
            } else if self.statusCode != 200 {
                var msg = self.errorBody
                if let data = self.errorBody.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let apiError = json["error"] as? [String: Any],
                   let m = apiError["message"] as? String {
                    msg = m
                }
                fputs("[Eureka] DeepSeek HTTP \(self.statusCode): \(msg)\n", stderr)
                self.panel?.finishStreamWithMessage("⚠️ API error (HTTP \(self.statusCode))\n\(msg.prefix(300))")
            } else {
                // Stream ended without [DONE] — show whatever arrived
                self.panel?.finishStream()
            }
        }
    }
}
