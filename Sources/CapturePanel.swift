import Cocoa

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
    private var tagSuggestionView: TagSuggestionView?
    private var tagSuggestionPanel: NSPanel?
    private var activeTagRange: NSRange?
    private var tagHistoryObserver: NSObjectProtocol?

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
    private let aiColor = NSColor(red: 0.55, green: 0.36, blue: 0.85, alpha: 1)
    private var topRegionH: CGFloat = 10
    private var quoteOffsetFromTop: CGFloat = 10
    private var questionLabel: NSTextField?
    private var submittedQuestion = ""
    private var dotsTimer: Timer?
    private var streamTimer: Timer?

    func show(selectedText: String, anchorPoint: NSPoint,
              screenshotPath: String? = nil,
              completion: @escaping (String) -> Void) {
        onSubmit = completion
        close()
        // Use the screen the mouse is on, not NSScreen.main — they differ on multi-monitor setups
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(anchorPoint, $0.frame, false) })
                ?? NSScreen.main else { return }

        hasQuote = !selectedText.isEmpty
        quotedText = selectedText
        hasScreenshot = screenshotPath != nil
        let thumbH: CGFloat = hasScreenshot ? 140 : 0
        quoteOffsetFromTop = 36
        topRegionH = hasQuote ? 46 : 10
        let ph: CGFloat = topRegionH + baseInputH + 14 + thumbH
        anchorY = anchorPoint.y

        // Position below the mouse, clamped with global screen coordinates
        // (non-main screens don't start at 0,0)
        let vis = screen.visibleFrame
        var px = anchorPoint.x - pw / 2
        var py = anchorPoint.y - ph - 10
        px = max(vis.minX + 12, min(px, vis.maxX - pw - 12))
        py = max(vis.minY + 12, min(py, vis.maxY - ph - 12))

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
            ctxBox.layer?.backgroundColor = EU.ctxBg.cgColor
            ctxBox.layer?.cornerRadius = 8
            ctxBox.identifier = NSUserInterfaceItemIdentifier("ctxBox")
            c.addSubview(ctxBox)
            ctxBoxView = ctxBox

            let label = NSTextField(labelWithString: txt)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = EU.muted
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSMakeRect(20, ctxY + 2, pw - 40, 14)
            c.addSubview(label)
            quoteLabel = label
            quoteOffsetFromTop = 36
        }

        // Source URL indicator
        // NSTextView in NSScrollView for auto-wrapping input
        let inputY: CGFloat = 14
        let sv = NSScrollView(frame: NSMakeRect(10, inputY, pw - 24, baseInputH))
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.borderType = .noBorder
        sv.drawsBackground = false

        let tv = NSTextView(frame: NSMakeRect(0, 0, pw - 24, baseInputH))
        tv.font = NSFont.systemFont(ofSize: 13)
        tv.textColor = EU.sub
        tv.drawsBackground = false
        tv.isRichText = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.textContainerInset = NSSize(width: 2, height: 2)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: pw - 32, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.textStorage?.delegate = self
        sv.documentView = tv
        c.addSubview(sv)
        scrollView = sv
        textView = tv

        isAIMode = false

        // Placeholder
        let placeholder = NSTextField(labelWithString: L("记个想法… 或 /指令 问AI", "Jot a thought… or / to ask AI"))
        placeholder.font = NSFont.systemFont(ofSize: 13)
        placeholder.textColor = EU.faint
        placeholder.frame = NSMakeRect(14, inputY + 2, 260, 20)
        placeholder.tag = 999
        c.addSubview(placeholder)

        // Hint
        let hint = NSTextField(labelWithString: "\u{21B5} save \u{00B7} esc")
        hint.font = NSFont.systemFont(ofSize: 10)
        hint.textColor = EU.faint
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
        tagHistoryObserver = NotificationCenter.default.addObserver(
            forName: TagHistory.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateTagSuggestions() }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            c.animator().alphaValue = 1
        }


        // Keyboard: Esc to close, Enter to submit
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard let self else { return ev }
            if self.tagSuggestionView != nil {
                switch ev.keyCode {
                case 53: self.hideTagSuggestions(); return nil       // Esc
                case 125: self.tagSuggestionView?.moveSelection(by: 1); return nil  // ↓
                case 126: self.tagSuggestionView?.moveSelection(by: -1); return nil // ↑
                case 36: // Enter completes; Shift+Enter keeps its newline behavior.
                    if ev.modifierFlags.contains(.shift) { return ev }
                    if let tv = self.textView, tv.hasMarkedText() { return ev }
                    self.tagSuggestionView?.selectCurrent(); return nil
                case 48: // Tab completes the selected tag.
                    if let tv = self.textView, tv.hasMarkedText() { return ev }
                    self.tagSuggestionView?.selectCurrent(); return nil
                default: break
                }
            }
            if ev.keyCode == 53 { self.close(); return nil }
            if ev.keyCode == 36 && !ev.modifierFlags.contains(.shift) {
                if let tv = self.textView, tv.hasMarkedText() { return ev }
                self.submit(); return nil
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
            self?.updateTagSuggestions()
        }
    }

    private func resizeToFit() {
        if answerPhase { return }
        guard let tv = textView, let sv = scrollView,
              let p = panel, let c = card else { return }

        // Hide/show placeholder
        if let ph = c.viewWithTag(999) {
            ph.isHidden = !tv.string.isEmpty
        }

        // Command mode visual feedback
        let text = tv.string
        let isCmd = text.hasPrefix("/") || text.hasPrefix("／")
        if isCmd {
            hintLabel?.stringValue = "↵ ask AI · esc"
            hintLabel?.textColor = aiColor
            if !isAIMode {
                isAIMode = true
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    c.layer?.borderWidth = 1.5
                    c.layer?.borderColor = aiColor.withAlphaComponent(0.35).cgColor
                    c.layer?.shadowColor = aiColor.cgColor
                    c.layer?.shadowOpacity = 0.15
                    c.layer?.shadowRadius = 12
                }
                updatingStyle = true
                let full = NSMutableAttributedString(attributedString: tv.attributedString())
                let range = NSRange(location: 0, length: full.length)
                full.addAttribute(.foregroundColor, value: aiColor, range: range)
                let prefixLen = min(1, full.length)
                if prefixLen > 0 {
                    let prefixRange = NSRange(location: 0, length: prefixLen)
                    full.addAttribute(.font, value: NSFont.systemFont(ofSize: 13, weight: .bold), range: prefixRange)
                    full.addAttribute(.kern, value: 3, range: prefixRange)
                }
                tv.textStorage?.setAttributedString(full)
                updatingStyle = false
            }
        } else if isAIMode {
            isAIMode = false
            hintLabel?.stringValue = "\u{21B5} save · esc"
            hintLabel?.textColor = EU.faint
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                c.layer?.borderWidth = 0
                c.layer?.shadowColor = NSColor.black.cgColor
                c.layer?.shadowOpacity = 0.10
                c.layer?.shadowRadius = 16
            }
            updatingStyle = true
            tv.textColor = EU.sub
            updatingStyle = false
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

    // MARK: Hashtag search and completion

    private func updateTagSuggestions() {
        guard !answerPhase, let tv = textView, panel != nil, !tv.hasMarkedText() else {
            hideTagSuggestions(); return
        }
        guard let match = activeHashtag(in: tv) else {
            hideTagSuggestions(); return
        }

        let tags = TagHistory.shared.suggestions(matching: match.query)
        guard !tags.isEmpty else { hideTagSuggestions(); return }
        activeTagRange = match.range

        let suggestion: TagSuggestionView
        if let existing = tagSuggestionView {
            suggestion = existing
        } else {
            suggestion = TagSuggestionView(frame: .zero)
            suggestion.onSelect = { [weak self] tag in self?.completeTag(tag) }
            let popup = NSPanel(
                contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false)
            popup.level = .floating
            popup.isOpaque = false
            popup.backgroundColor = .clear
            popup.hasShadow = false
            popup.contentView = suggestion
            panel?.addChildWindow(popup, ordered: .above)
            popup.orderFront(nil)
            tagSuggestionPanel = popup
            tagSuggestionView = suggestion
        }
        suggestion.update(tags: tags)
        positionTagSuggestions(suggestion)
    }

    private func activeHashtag(in tv: NSTextView) -> (range: NSRange, query: String)? {
        let selection = tv.selectedRange()
        guard selection.length == 0 else { return nil }
        let ns = tv.string as NSString
        guard selection.location <= ns.length else { return nil }
        let prefix = ns.substring(to: selection.location) as NSString
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:^|[\s\(\[\{])#([\p{L}\p{N}_/-]*)$"#
        ), let match = regex.firstMatch(
            in: prefix as String, range: NSRange(location: 0, length: prefix.length)
        ) else { return nil }
        let queryRange = match.range(at: 1)
        let hashRange = NSRange(location: queryRange.location - 1, length: queryRange.length + 1)
        return (hashRange, prefix.substring(with: queryRange))
    }

    private func positionTagSuggestions(_ suggestion: TagSuggestionView) {
        guard let tv = textView, let p = panel else { return }
        let caret = tv.firstRect(forCharacterRange: tv.selectedRange(), actualRange: nil)
        let width: CGFloat = 210
        let height = suggestion.preferredHeight
        let screen = NSScreen.screens.first { NSMouseInRect(caret.origin, $0.frame, false) }
            ?? p.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? .zero
        var x = max(visible.minX + 8, min(caret.minX, visible.maxX - width - 8))
        var y = caret.minY - height - 6
        if y < visible.minY + 8 { y = caret.maxY + 6 }
        x = min(x, visible.maxX - width - 8)
        let frame = NSRect(x: x, y: y, width: width, height: height)
        tagSuggestionPanel?.setFrame(frame, display: true)
        suggestion.frame = NSRect(origin: .zero, size: frame.size)
    }

    private func completeTag(_ tag: String) {
        guard let tv = textView, let range = activeTagRange else { return }
        let ns = tv.string as NSString
        let needsSpace = NSMaxRange(range) >= ns.length
            || !(ns.substring(with: NSRange(location: NSMaxRange(range), length: 1))
                .first?.isWhitespace ?? false)
        let replacement = "#\(tag)" + (needsSpace ? " " : "")
        tv.insertText(replacement, replacementRange: range)
        hideTagSuggestions()
    }

    private func hideTagSuggestions() {
        if let popup = tagSuggestionPanel {
            panel?.removeChildWindow(popup)
            popup.orderOut(nil)
        }
        tagSuggestionPanel = nil
        tagSuggestionView = nil
        activeTagRange = nil
    }

    private func submit() {
        let typed = textView?.string
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = typed.isEmpty ? quotedText : typed
        // A screenshot is worth saving even without a comment
        guard !text.isEmpty || hasScreenshot else { close(); return }
        let isAI = text.hasPrefix("/") || text.hasPrefix("／")
        if !isAI {
            close()
        }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        onSubmit?(text)
    }

    // MARK: Streaming answer display

    private var answerPhase = false

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

    func showStreamingAnswer() {
        guard let p = panel, let c = card, let tv = textView, let sv = scrollView else { return }

        answerPhase = true
        submittedQuestion = tv.string
        tv.textStorage?.setAttributedString(NSAttributedString(string: ""))
        if let ph = c.viewWithTag(999) { ph.isHidden = true }
        questionLabel?.removeFromSuperview()
        screenshotView?.isHidden = true

        // Show styled question label where input was
        let ql = NSTextField(labelWithString: "")
        ql.lineBreakMode = .byTruncatingTail
        ql.attributedStringValue = Self.styledQuestion(submittedQuestion)
        c.addSubview(ql, positioned: .above, relativeTo: nil)
        questionLabel = ql

        let qY = sv.frame.origin.y + 2
        ql.frame = NSMakeRect(16, qY, pw - 32, 16)

        // Compact loading state: the question starts at the same top inset as
        // the final answer instead of inheriting the selected-text preview gap.
        let topPadding: CGFloat = 16
        let questionH: CGFloat = 16
        let questionToDots: CGFloat = 12
        let dotsH: CGFloat = 20
        let footerH: CGFloat = 12
        let totalH = topPadding + questionH + questionToDots + dotsH + footerH

        var frame = p.frame
        let dy = totalH - frame.size.height
        frame.origin.y -= dy
        frame.size.height = totalH
        p.setFrame(frame, display: true)
        c.frame = NSMakeRect(0, 0, pw, totalH)

        ctxBoxView?.isHidden = true
        quoteLabel?.isHidden = true
        let newQY = totalH - topPadding - questionH
        ql.frame = NSMakeRect(16, newQY, pw - 32, questionH)

        sv.frame = NSMakeRect(16, footerH, pw - 32, dotsH)
        sv.wantsLayer = true
        sv.layer?.masksToBounds = true
        tv.isEditable = false
        hintLabel?.isHidden = true

        // Dots animation
        dotsTimer?.invalidate()
        var tick = 0
        dotsTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak tv] _ in
            guard let tv = tv else { return }
            tick += 1
            let dots = String(repeating: "·", count: (tick % 3) + 1)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: EU.muted
            ]
            tv.textStorage?.setAttributedString(NSAttributedString(string: dots, attributes: attrs))
        }
    }

    func appendStreamChunk(_ chunk: String) {
        answerBuffer += chunk
    }

    private var answerBuffer = ""

    func finishStream() {
        dotsTimer?.invalidate(); dotsTimer = nil
        showAnswer(answerBuffer)
        answerBuffer = ""
    }

    func finishStreamWithMessage(_ message: String) {
        dotsTimer?.invalidate(); dotsTimer = nil
        showAnswer(message)
    }

    private func showAnswer(_ text: String) {
        guard let p = panel, let c = card, let tv = textView, let sv = scrollView else { return }

        tv.textStorage?.setAttributedString(NSAttributedString(string: ""))

        // Add separator
        c.subviews.filter { $0.identifier?.rawValue == "sep" }.forEach { $0.removeFromSuperview() }
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        sep.identifier = NSUserInterfaceItemIdentifier("sep")
        c.addSubview(sep)

        if clickMonitor == nil {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.close()
            }
        }

        let topPadding: CGFloat = 16
        let questionH: CGFloat = 16
        let questionToSeparator: CGFloat = 10
        let separatorToAnswer: CGFloat = 10
        let footerH: CGFloat = 24
        let maxAnswerH: CGFloat = 260

        let answer = Self.renderMarkdown(text)
        var revealedLength = 0

        streamTimer?.invalidate()
        streamTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) {
            [weak self, weak tv, weak sv, weak p, weak c] timer in
            guard let self = self, let tv = tv, let sv = sv, let p = p, let c = c else {
                timer.invalidate(); return
            }
            let chunkSize = max(1, answer.length / 60)
            revealedLength = min(revealedLength + chunkSize, answer.length)
            tv.textStorage?.setAttributedString(answer.attributedSubstring(
                from: NSRange(location: 0, length: revealedLength)))

            tv.layoutManager?.ensureLayout(for: tv.textContainer!)
            let usedRect = tv.layoutManager?.usedRect(for: tv.textContainer!) ?? .zero
            let answerH = max(18, min(ceil(usedRect.height) + 4, maxAnswerH))
            let totalH = topPadding + questionH + questionToSeparator + 1
                + separatorToAnswer + answerH + footerH

            var frame = p.frame
            let dy = totalH - frame.size.height
            if abs(dy) > 1 {
                frame.origin.y -= dy
                frame.size.height = totalH
                p.setFrame(frame, display: true)
                c.frame = NSMakeRect(0, 0, self.pw, totalH)
            }

            self.ctxBoxView?.isHidden = true
            self.quoteLabel?.isHidden = true
            let qY = totalH - topPadding - questionH
            self.questionLabel?.frame = NSMakeRect(16, qY, self.pw - 32, questionH)

            let sepY = qY - questionToSeparator
            c.subviews.first { $0.identifier?.rawValue == "sep" }?.frame =
                NSMakeRect(16, sepY, self.pw - 32, 0.5)

            sv.frame = NSMakeRect(16, footerH, self.pw - 32,
                                  max(18, sepY - separatorToAnswer - footerH))
            sv.hasVerticalScroller = answerH >= maxAnswerH

            self.hintLabel?.isHidden = false
            self.hintLabel?.frame = NSMakeRect(self.pw - 70, 2, 60, 12)
            self.hintLabel?.stringValue = "esc"
            self.hintLabel?.font = NSFont.systemFont(ofSize: 10)
            self.hintLabel?.textColor = EU.faint

            tv.scrollToEndOfDocument(nil)

            if revealedLength >= answer.length {
                timer.invalidate()
                self.streamTimer = nil
            }
        }
    }

    private static func renderMarkdown(_ text: String) -> NSAttributedString {
        MarkdownRenderer.render(text)
    }

    private static func styledQuestion(_ text: String) -> NSAttributedString {
        let aiCol = NSColor(red: 0.55, green: 0.36, blue: 0.85, alpha: 1)
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: EU.text
        ]
        let result = NSMutableAttributedString(string: text, attributes: base)
        if text.hasPrefix("/") || text.hasPrefix("／") {
            let slashAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: aiCol,
                .kern: 2
            ]
            result.setAttributes(slashAttrs, range: NSRange(location: 0, length: 1))
        }
        return result
    }

    var isOpen: Bool { panel != nil }

    func close() {
        fputs("[Eureka] CapturePanel.close()\n", stderr)
        dotsTimer?.invalidate(); dotsTimer = nil
        streamTimer?.invalidate(); streamTimer = nil
        answerPhase = false; answerBuffer = ""
        questionLabel?.removeFromSuperview(); questionLabel = nil
        hideTagSuggestions()
        if let observer = tagHistoryObserver {
            NotificationCenter.default.removeObserver(observer)
            tagHistoryObserver = nil
        }
        panel?.close(); panel = nil
        screenshotView = nil
        ctxBoxView = nil
        isAIMode = false
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    static func truncate(_ s: String, max: Int) -> String {
        let flat = s.replacingOccurrences(of: "\n", with: " ")
        if flat.count <= max { return flat }
        let half = (max - 3) / 2
        return "\(flat.prefix(half))...\(flat.suffix(half))"
    }
}
