import AppKit
import cmark_gfm
import cmark_gfm_extensions

/// Converts GitHub Flavored Markdown to an AppKit attributed string through
/// cmark-gfm's HTML renderer and Apple's mature HTML text importer.
enum MarkdownRenderer {
    private static let extensions = [
        "autolink", "strikethrough", "tagfilter", "tasklist", "table"
    ]

    static func render(_ markdown: String) -> NSAttributedString {
        guard let html = renderHTML(markdown) else {
            return fallback(markdown)
        }

        let document = """
        <!doctype html>
        <html><head><meta charset="utf-8"><style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 13px;
            color: #262626;
            line-height: 1.45;
        }
        h1, h2, h3, h4, h5, h6 {
            margin: 0.9em 0 0.35em;
            line-height: 1.25;
        }
        h1 { font-size: 1.55em; }
        h2 { font-size: 1.35em; }
        h3 { font-size: 1.2em; }
        h4, h5, h6 { font-size: 1.05em; }
        p { margin: 0 0 0.65em; }
        ul, ol { margin: 0.2em 0 0.7em 1.25em; padding: 0; }
        li { margin: 0.15em 0; }
        blockquote {
            margin: 0.45em 0;
            padding: 0.1em 0 0.1em 0.75em;
            border-left: 3px solid #8c8c8c;
            color: #555;
        }
        pre {
            margin: 0.55em 0;
            padding: 0.6em 0.75em;
            background: #f3f4f6;
            white-space: pre-wrap;
        }
        code { font-family: Menlo, monospace; font-size: 0.92em; }
        :not(pre) > code { background: #f3f4f6; }
        hr { border: 0; border-top: 1px solid #d9d9d9; margin: 0.75em 0; }
        table { border-collapse: collapse; margin: 0.5em 0 0.75em; width: 100%; }
        th, td { border: 1px solid #d9d9d9; padding: 0.35em 0.5em; }
        th { background: #f5f5f5; font-weight: 600; }
        a { color: #6f46bf; }
        </style></head><body>\(html)</body></html>
        """

        guard let data = document.data(using: .utf8),
              let rendered = try? NSMutableAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil)
        else {
            return fallback(markdown)
        }

        // The importer may apply a body background to every run. The panel itself
        // owns its background, so remove only that document-level artifact while
        // retaining code-block and inline-code backgrounds.
        if rendered.length > 0 {
            let fullRange = NSRange(location: 0, length: rendered.length)
            rendered.enumerateAttribute(.backgroundColor, in: fullRange) { value, range, _ in
                guard let color = value as? NSColor,
                      color.usingColorSpace(.deviceRGB)?.whiteComponent ?? 0 > 0.99
                else { return }
                rendered.removeAttribute(.backgroundColor, range: range)
            }
        }
        return rendered
    }

    private static func renderHTML(_ markdown: String) -> String? {
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(CMARK_OPT_DEFAULT) else { return nil }
        defer { cmark_parser_free(parser) }

        for name in extensions {
            name.withCString { pointer in
                if let syntaxExtension = cmark_find_syntax_extension(pointer) {
                    cmark_parser_attach_syntax_extension(parser, syntaxExtension)
                }
            }
        }

        markdown.withCString { pointer in
            cmark_parser_feed(parser, pointer, strlen(pointer))
        }
        guard let document = cmark_parser_finish(parser) else { return nil }
        defer { cmark_node_free(document) }

        guard let htmlPointer = cmark_render_html(
            document,
            CMARK_OPT_DEFAULT,
            cmark_parser_get_syntax_extensions(parser))
        else { return nil }
        defer { free(htmlPointer) }
        return String(cString: htmlPointer)
    }

    private static func fallback(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: EU.body
        ])
    }
}

private extension NSColor {
    var whiteComponent: CGFloat? {
        guard colorSpace.colorSpaceModel == .gray else { return nil }
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        getWhite(&white, alpha: &alpha)
        return white
    }
}
