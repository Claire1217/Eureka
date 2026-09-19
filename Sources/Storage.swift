import Cocoa

class LocalStorage {
    static let shared = LocalStorage()
    // Starts at 1, not 0: the floating bubble shows palette[0] at launch and moves to the next
    // colour on every save, so a card and the bubble it came from now share their colour.
    private var colorIndex = 1

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

    var llmApiKey: String {
        get { UserDefaults.standard.string(forKey: "llmApiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "llmApiKey") }
    }

    var llmApiBase: String {
        get { UserDefaults.standard.string(forKey: "llmApiBase") ?? "https://api.deepseek.com/chat/completions" }
        set { UserDefaults.standard.set(newValue, forKey: "llmApiBase") }
    }

    var llmModel: String {
        get { UserDefaults.standard.string(forKey: "llmModel") ?? "deepseek-chat" }
        set { UserDefaults.standard.set(newValue, forKey: "llmModel") }
    }

    /// Override with: defaults write com.eureka.app llmSystemPrompt "…"
    var llmSystemPrompt: String {
        let custom = UserDefaults.standard.string(forKey: "llmSystemPrompt") ?? ""
        return custom.isEmpty
            ? "You are a concise assistant. Reply in the language the question is written in; keep technical terms in English. Stay under 150 words."
            : custom
    }

    /// Walk up from `path` to the folder containing `.obsidian`.
    /// Returns nil if the path is not inside an Obsidian vault.
    static func findVaultRoot(from path: String) -> String? {
        let fm = FileManager.default
        var dir = NSString(string: path).expandingTildeInPath
        while dir != "/" && !dir.isEmpty {
            if fm.fileExists(atPath: "\(dir)/.obsidian") { return dir }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return nil
    }

    /// Auto-install thought-cards.css into the Obsidian vault's snippets folder
    func installObsidianSnippet() {
        let fm = FileManager.default
        guard let dir = LocalStorage.findVaultRoot(from: vaultPath) else { return }

        let snippetsDir = "\(dir)/.obsidian/snippets"
        try? fm.createDirectory(atPath: snippetsDir, withIntermediateDirectories: true)

        let cssPath = "\(snippetsDir)/thought-cards.css"
        if !fm.fileExists(atPath: cssPath) {
            try? thoughtCardsCSS.write(toFile: cssPath, atomically: true, encoding: .utf8)
        }

        // Enable in appearance.json
        let appearancePath = "\(dir)/.obsidian/appearance.json"
        var appearance: [String: Any] = [:]
        if let data = fm.contents(atPath: appearancePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            appearance = json
        }
        var snippets = appearance["enabledCssSnippets"] as? [String] ?? []
        if !snippets.contains("thought-cards") {
            snippets.append("thought-cards")
            appearance["enabledCssSnippets"] = snippets
            if let data = try? JSONSerialization.data(withJSONObject: appearance, options: .prettyPrinted) {
                try? data.write(to: URL(fileURLWithPath: appearancePath))
            }
        }
    }

    static func stamp(_ format: String, _ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Prefix every line so multi-line text stays inside the callout / blockquote.
    static func quoteLines(_ text: String, prefix: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.isEmpty ? prefix.trimmingCharacters(in: .whitespaces) : prefix + $0 }
            .joined(separator: "\n")
    }

    static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func nextColor() -> String {
        let c = THOUGHT_COLORS[colorIndex % THOUGHT_COLORS.count]
        colorIndex = (colorIndex + 1) % THOUGHT_COLORS.count
        return c
    }

    func save(thought: String, selectedText: String, appName: String,
              browserURL: String, screenshotPath: String?) -> (ok: Bool, savedTo: String) {
        if backend == "notes" {
            return saveToAppleNotes(thought: thought, selectedText: selectedText,
                                    appName: appName, browserURL: browserURL,
                                    screenshotPath: screenshotPath)
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
        let folder = NSString(string: vaultPath).expandingTildeInPath
        let fm = FileManager.default

        let now = Date()
        let dateStr = LocalStorage.stamp("yyyy-MM-dd", now)
        let timeStr = LocalStorage.stamp("HH:mm", now)

        let dayDir = "\(folder)/\(dateStr)"
        do {
            try fm.createDirectory(atPath: dayDir, withIntermediateDirectories: true)
        } catch {
            fputs("[Eureka] Failed to create \(dayDir): \(error)\n", stderr)
            return (false, "")
        }
        let fileName = "Thoughts.md"
        let filePath = "\(dayDir)/\(fileName)"
        // savedTo must be relative to vault root for obsidian:// deep links
        let savedTo: String
        if let vaultRoot = LocalStorage.findVaultRoot(from: folder),
           filePath.hasPrefix(vaultRoot + "/") {
            savedTo = String(filePath.dropFirst(vaultRoot.count + 1))
        } else {
            savedTo = "\(dateStr)/\(fileName)"
        }

        var source = ""
        if !browserURL.isEmpty, !browserURL.hasPrefix("app://"),
           let parsed = URL(string: browserURL) {
            let host = parsed.host ?? ""
            let path = parsed.path.count <= 40 ? parsed.path : String(parsed.path.prefix(37)) + "..."
            source = "[\(host)\(path)](\(browserURL))"
        }

        var screenshotFilename: String? = nil
        if let path = screenshotPath, let data = fm.contents(atPath: path) {
            screenshotFilename = "eureka_\(LocalStorage.stamp("yyyyMMdd_HHmmss", now)).png"
            let attachDir = "\(dayDir)/attachments"
            try? fm.createDirectory(atPath: attachDir, withIntermediateDirectories: true)
            fm.createFile(atPath: "\(attachDir)/\(screenshotFilename!)", contents: data)
            try? fm.removeItem(atPath: path)
        }

        let color = nextColor()
        var lines = [String]()
        lines.append("")
        lines.append("> [!thought-\(color)] \(timeStr)")
        if !thought.isEmpty {
            // Shift+Enter thoughts span several lines — each one needs the "> " prefix
            lines.append(LocalStorage.quoteLines(thought, prefix: "> "))
        }
        if let sf = screenshotFilename {
            lines.append("> ![[\(sf)]]")
        }
        if !selectedText.isEmpty {
            var safe = selectedText
            safe = safe.replacingOccurrences(of: "```", with: "` ` `")
            let quoted = LocalStorage.quoteLines(safe, prefix: "> > ")
            let sourceTag = !source.isEmpty ? " \u{3010}\(source)\u{3011}" : (!appName.isEmpty ? " \u{3010}\(appName)\u{3011}" : "")
            lines.append("\(quoted)\(sourceTag)")
        } else if !source.isEmpty {
            lines.append("> \(source)")
        }
        lines.append("")

        let entry = lines.joined(separator: "\n")

        if fm.fileExists(atPath: filePath) {
            guard let fh = FileHandle(forWritingAtPath: filePath) else {
                fputs("[Eureka] Failed to open \(filePath) for writing\n", stderr)
                return (false, savedTo)
            }
            fh.seekToEndOfFile()
            fh.write(entry.data(using: .utf8)!)
            fh.closeFile()
        } else {
            let header = "# Random Thoughts \u{2014} \(dateStr)\n"
            do {
                try (header + entry).write(toFile: filePath, atomically: true, encoding: .utf8)
            } catch {
                fputs("[Eureka] Failed to write \(filePath): \(error)\n", stderr)
                return (false, savedTo)
            }
        }

        return (true, savedTo)
    }

    private let thoughtCardsCSS = """
    /* Eureka — styled thought callouts */
    .callout[data-callout^="thought"] {
      --callout-icon: lucide-sparkles;
      border: none; border-radius: 10px; padding: 8px 14px;
      margin: 6px 0; box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    }
    .callout[data-callout^="thought"] .callout-title {
      font-size: 0.78em; opacity: 0.6; font-weight: 400; padding: 0;
    }
    .callout[data-callout^="thought"] .callout-title-inner { font-weight: 400; }
    .callout[data-callout^="thought"] .callout-content { padding: 2px 0 0 0; font-size: 0.95em; }
    .callout[data-callout^="thought"] .callout-content blockquote {
      border-left: 2px solid rgba(0,0,0,0.15); margin: 4px 0 0 0;
      padding: 2px 0 2px 10px; font-size: 0.88em; opacity: 0.7; font-style: italic;
    }
    .callout[data-callout="thought-coral"] { --callout-color: 230,107,128; background: linear-gradient(135deg, rgba(245,166,115,0.13), rgba(230,107,128,0.13)); }
    .callout[data-callout="thought-blue"] { --callout-color: 97,128,217; background: linear-gradient(135deg, rgba(140,199,242,0.13), rgba(97,128,217,0.13)); }
    .callout[data-callout="thought-purple"] { --callout-color: 158,115,209; background: linear-gradient(135deg, rgba(217,179,242,0.13), rgba(158,115,209,0.13)); }
    .callout[data-callout="thought-green"] { --callout-color: 89,179,158; background: linear-gradient(135deg, rgba(153,230,191,0.13), rgba(89,179,158,0.13)); }
    .callout[data-callout="thought-amber"] { --callout-color: 224,148,77; background: linear-gradient(135deg, rgba(242,204,115,0.13), rgba(224,148,77,0.13)); }
    .callout[data-callout="thought-olive"] { --callout-color: 122,184,102; background: linear-gradient(135deg, rgba(179,217,140,0.13), rgba(122,184,102,0.13)); }
    .callout[data-callout="thought-pink"] { --callout-color: 209,89,122; background: linear-gradient(135deg, rgba(242,140,166,0.13), rgba(209,89,122,0.13)); }
    .callout[data-callout="thought-steel"] { --callout-color: 82,148,191; background: linear-gradient(135deg, rgba(128,191,224,0.13), rgba(82,148,191,0.13)); }
    .callout[data-callout="thought"] { --callout-color: 140,140,160; background: rgba(140,140,160,0.08); }
    """

    private func saveToAppleNotes(thought: String, selectedText: String,
                                  appName: String, browserURL: String,
                                  screenshotPath: String?) -> (ok: Bool, savedTo: String) {
        let now = Date()
        let dateStr = LocalStorage.stamp("yyyy-MM-dd", now)
        let timeStr = LocalStorage.stamp("HH:mm", now)
        let noteTitle = "Thoughts \u{2014} \(dateStr)"
        let esc = LocalStorage.escapeHTML

        var body = "\u{1F535} \(timeStr)"
        if !thought.isEmpty { body += "<br>\(esc(thought))" }

        // Rewriting a note's body through AppleScript drops its attachments, so the
        // screenshot is kept as a file and referenced by path instead of embedded.
        if let path = screenshotPath, FileManager.default.fileExists(atPath: path) {
            let fm = FileManager.default
            let dir = NSString(string: "~/Pictures/Eureka").expandingTildeInPath
            let dest = "\(dir)/eureka_\(LocalStorage.stamp("yyyyMMdd_HHmmss_SSS", now)).png"
            do {
                try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try fm.moveItem(atPath: path, toPath: dest)
                body += "<br>\u{1F4CE} \(esc(dest))"
            } catch {
                fputs("[Eureka] Failed to keep screenshot: \(error)\n", stderr)
                try? fm.removeItem(atPath: path)
            }
        }

        var sourceTag = ""
        if !browserURL.isEmpty, !browserURL.hasPrefix("app://") {
            let href = esc(browserURL).replacingOccurrences(of: "\"", with: "&quot;")
            let host = esc(URL(string: browserURL)?.host ?? browserURL)
            sourceTag = " <span style=\"font-style:normal;font-size:0.8em\">\u{2014} <a href=\"\(href)\">\(host)</a></span>"
        } else if !appName.isEmpty {
            sourceTag = " <span style=\"font-style:normal;font-size:0.8em\">\u{2014} \(esc(appName))</span>"
        }
        if !selectedText.isEmpty {
            body += "<br><span style=\"font-style:italic;color:#8e8e93\">\(esc(selectedText))\(sourceTag)</span>"
        } else if !sourceTag.isEmpty, !browserURL.isEmpty {
            body += "<br><span style=\"color:#8e8e93\">\(sourceTag)</span>"
        }

        // Backslashes must be escaped before quotes, or the AppleScript breaks
        let escaped = body.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
                          .replacingOccurrences(of: "\r\n", with: "<br>")
                          .replacingOccurrences(of: "\n", with: "<br>")

        // `whose name is` lets Notes do the lookup instead of walking every note
        let script = """
        tell application "Notes"
            set matches to (notes of default account whose name is "\(noteTitle)")
            if (count of matches) > 0 then
                set n to item 1 of matches
                set body of n to (body of n) & "<br><br>" & "\(escaped)"
            else
                make new note at default account with properties {name:"\(noteTitle)", body:"\(escaped)"}
            end if
        end tell
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = errPipe
        do {
            try proc.run()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            if proc.terminationStatus != 0 {
                // e.g. -1743: Automation permission for Notes was denied
                let msg = String(data: errData, encoding: .utf8) ?? ""
                fputs("[Eureka] Apple Notes save failed: \(msg)\n", stderr)
            }
            return (proc.terminationStatus == 0, noteTitle)
        } catch {
            fputs("[Eureka] Apple Notes error: \(error)\n", stderr)
            return (false, "")
        }
    }
}
