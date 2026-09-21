import Cocoa

/// Lightweight hashtag search results attached to the capture card.
final class TagSuggestionView: NSView {
    private var labels = [NSTextField]()
    private(set) var tags = [String]()
    private(set) var selectedIndex = 0
    private var mouseMonitor: Any?
    var onSelect: ((String) -> Void)?

    private let rowHeight: CGFloat = 28

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.cornerRadius = 9
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.14
        layer?.shadowRadius = 10
        layer?.shadowOffset = CGSize(width: 0, height: -2)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installMouseMonitorIfNeeded()
    }

    deinit {
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
    }

    var preferredHeight: CGFloat { CGFloat(tags.count) * rowHeight + 8 }

    func update(tags: [String]) {
        self.tags = tags
        selectedIndex = min(selectedIndex, max(0, tags.count - 1))
        rebuildRows()
        installMouseMonitorIfNeeded()
    }

    func moveSelection(by delta: Int) {
        guard !tags.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + tags.count) % tags.count
        updateSelectionStyle()
    }

    func selectCurrent() {
        guard tags.indices.contains(selectedIndex) else { return }
        onSelect?(tags[selectedIndex])
    }

    private func rebuildRows() {
        labels.forEach { $0.removeFromSuperview() }
        labels.removeAll()
        for (index, tag) in tags.enumerated() {
            let label = NSTextField(labelWithString: "#\(tag)")
            label.font = NSFont.systemFont(ofSize: 13, weight: index == selectedIndex ? .semibold : .regular)
            label.lineBreakMode = .byTruncatingTail
            label.wantsLayer = true
            label.layer?.cornerRadius = 6
            label.tag = index
            addSubview(label)
            labels.append(label)
        }
        needsLayout = true
        updateSelectionStyle()
    }

    override func layout() {
        super.layout()
        for (index, label) in labels.enumerated() {
            let y = bounds.height - 4 - CGFloat(index + 1) * rowHeight
            label.frame = NSRect(x: 4, y: y, width: bounds.width - 8, height: rowHeight)
        }
    }

    private func updateSelectionStyle() {
        for (index, label) in labels.enumerated() {
            let selected = index == selectedIndex
            label.font = NSFont.systemFont(ofSize: 13, weight: selected ? .semibold : .regular)
            label.textColor = selected ? NSColor.controlAccentColor : EU.sub
            label.backgroundColor = selected
                ? NSColor.controlAccentColor.withAlphaComponent(0.10)
                : .clear
            label.drawsBackground = selected
            label.alignment = .left
            // labelWithString has no content inset; add spacing with a leading thin space.
            label.stringValue = "  #\(tags[index])"
        }
    }

    private func installMouseMonitorIfNeeded() {
        guard mouseMonitor == nil, window != nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) {
            [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            let point = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(point) else { return event }
            let row = Int((self.bounds.height - 4 - point.y) / self.rowHeight)
            guard self.tags.indices.contains(row) else { return event }
            self.selectedIndex = row
            self.updateSelectionStyle()
            if event.type == .leftMouseDown {
                self.selectCurrent()
                return nil
            }
            return event
        }
    }
}
