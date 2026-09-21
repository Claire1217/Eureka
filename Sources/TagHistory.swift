import Foundation

/// Persistent, recency-ordered hashtag history used by the capture autocomplete UI.
final class TagHistory {
    static let shared = TagHistory()
    static let didChangeNotification = Notification.Name("EurekaTagHistoryDidChange")

    private let defaultsKey = "recentHashtags"
    private let lock = NSLock()
    private var scannedVaultPaths = Set<String>()
    private let maximumTags = 100

    private init() {}

    func suggestions(matching query: String, limit: Int = 6) -> [String] {
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let tags = knownTags()
        if needle.isEmpty { return Array(tags.prefix(limit)) }

        // Prefix hits are the most useful while typing; substring hits make this a
        // small search surface once the history grows beyond a handful of tags.
        let prefix = tags.filter { normalized($0).hasPrefix(needle) }
        let contains = tags.filter {
            let value = normalized($0)
            return !value.hasPrefix(needle) && value.contains(needle)
        }
        return Array((prefix + contains).prefix(limit))
    }

    func recordTags(in text: String) {
        merge(Self.extractTags(from: text), preferNewTags: true)
    }

    /// Imports hashtags from Eureka's existing Obsidian thought files once per vault per launch.
    /// Future saves are recorded directly, so this scan is only a backwards-compatibility seed.
    func refreshFromObsidian(at rawPath: String) {
        let path = NSString(string: rawPath).expandingTildeInPath
        guard !path.isEmpty else { return }

        lock.lock()
        let shouldScan = scannedVaultPaths.insert(path).inserted
        lock.unlock()
        guard shouldScan else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            var files = [URL]()
            for case let url as URL in enumerator where url.lastPathComponent == "Thoughts.md" {
                files.append(url)
                if files.count >= 500 { break }
            }
            files.sort { $0.path > $1.path } // yyyy-MM-dd folders: newest first

            var imported = [String]()
            for url in files {
                guard let data = try? Data(contentsOf: url), data.count <= 4_000_000,
                      let markdown = String(data: data, encoding: .utf8) else { continue }
                imported.append(contentsOf: Self.extractThoughtTags(from: markdown))
            }
            self.merge(imported, preferNewTags: false)
        }
    }

    static func extractTags(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<![\p{L}\p{N}_])#([\p{L}\p{N}_/-]+)"#
        ) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            guard $0.numberOfRanges > 1 else { return nil }
            return ns.substring(with: $0.range(at: 1))
        }
    }

    private static func extractThoughtTags(from markdown: String) -> [String] {
        var tags = [String]()
        // Eureka stores user-authored thought lines as top-level callout content (`> `).
        // Skip callout titles, nested selected-text quotes, images and source-only links.
        for line in markdown.components(separatedBy: .newlines).reversed() {
            guard line.hasPrefix("> "), !line.hasPrefix("> > "),
                  !line.hasPrefix("> [!thought-"), !line.hasPrefix("> ![[") else { continue }
            let content = String(line.dropFirst(2))
            if content.hasPrefix("http://") || content.hasPrefix("https://") || content.hasPrefix("[") {
                continue
            }
            tags.append(contentsOf: extractTags(from: content))
        }
        return tags
    }

    private func normalized(_ tag: String) -> String {
        tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func knownTags() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    }

    private func merge(_ incoming: [String], preferNewTags: Bool) {
        guard !incoming.isEmpty else { return }
        lock.lock()
        let existing = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        let ordered = preferNewTags ? Array(incoming.reversed()) + existing : existing + incoming
        var seen = Set<String>()
        var merged = [String]()
        for tag in ordered {
            let key = tag.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !tag.isEmpty, seen.insert(key).inserted else { continue }
            merged.append(tag)
            if merged.count == maximumTags { break }
        }
        let changed = merged != existing
        if changed { UserDefaults.standard.set(merged, forKey: defaultsKey) }
        lock.unlock()

        if changed {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
            }
        }
    }
}
