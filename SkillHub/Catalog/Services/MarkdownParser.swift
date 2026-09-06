import Foundation

/// Block-level markdown splitter. Inline formatting is left to `AttributedString(markdown:)`.
nonisolated enum MarkdownParser {
    static func blocks(from raw: String) -> [MarkdownBlock] {
        let body = Frontmatter.parse(raw).body
        let lines = body.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                index += 1
                var code: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.code(code.joined(separator: "\n")))
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.rule)
                index += 1
                continue
            }

            if let heading = heading(from: trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }

            if trimmed.hasPrefix("> ") || trimmed == ">" {
                var quoted: [String] = []
                while index < lines.count {
                    let next = lines[index].trimmingCharacters(in: .whitespaces)
                    if next.hasPrefix("> ") {
                        quoted.append(String(next.dropFirst(2)))
                    } else if next == ">" {
                        quoted.append("")
                    } else {
                        break
                    }
                    index += 1
                }
                blocks.append(.quote(quoted.joined(separator: "\n")))
                continue
            }

            if isTableRow(trimmed) {
                var rows: [[String]] = []
                while index < lines.count, isTableRow(lines[index].trimmingCharacters(in: .whitespaces)) {
                    let cells = tableCells(lines[index])
                    if !isTableSeparator(cells) { rows.append(cells) }
                    index += 1
                }
                if let header = rows.first {
                    blocks.append(.table(header, Array(rows.dropFirst())))
                }
                continue
            }

            if isBullet(trimmed) {
                var items: [String] = []
                while index < lines.count, isBullet(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(stripBullet(lines[index].trimmingCharacters(in: .whitespaces)))
                    index += 1
                }
                blocks.append(.bullets(items))
                continue
            }

            if isNumbered(trimmed) {
                var items: [String] = []
                while index < lines.count, isNumbered(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(stripNumber(lines[index].trimmingCharacters(in: .whitespaces)))
                    index += 1
                }
                blocks.append(.numbered(items))
                continue
            }

            var paragraph = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || startsBlock(next) { break }
                paragraph.append(next)
                index += 1
            }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
        }

        return blocks
    }

    /// Drops a leading H1 that merely repeats the item's own name, so the document doesn't show the title twice.
    static func skippingRedundantTitle(_ blocks: [MarkdownBlock], title: String) -> [MarkdownBlock] {
        guard case .heading(1, let text) = blocks.first else { return blocks }
        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()
        let name = title.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").lowercased()
        if compact == name || text.caseInsensitiveCompare(title) == .orderedSame {
            return Array(blocks.dropFirst())
        }
        return blocks
    }

    private static func heading(from trimmed: String) -> MarkdownBlock? {
        guard trimmed.hasPrefix("#") else { return nil }
        let hashes = trimmed.prefix { $0 == "#" }.count
        guard hashes <= 6, trimmed.count > hashes else { return nil }
        let afterHashes = trimmed.index(trimmed.startIndex, offsetBy: hashes)
        guard trimmed[afterHashes] == " " else { return nil }
        return .heading(hashes, String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces))
    }

    private static func startsBlock(_ line: String) -> Bool {
        line.hasPrefix("#") || line.hasPrefix("```") || line.hasPrefix("> ")
            || isBullet(line) || isNumbered(line) || isTableRow(line) || line == "---"
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.hasPrefix("|") && line.dropFirst().contains("|")
    }

    private static func isTableSeparator(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { cell in
            cell.replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespaces)
                .isEmpty
        }
    }

    private static func tableCells(_ line: String) -> [String] {
        var parts = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.first == "" { parts.removeFirst() }
        if parts.last == "" { parts.removeLast() }
        return parts
    }

    private static func isBullet(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ")
    }

    private static func stripBullet(_ line: String) -> String {
        isBullet(line) ? String(line.dropFirst(2)) : line
    }

    private static func isNumbered(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: ".") else { return false }
        let prefix = line[..<dot]
        return !prefix.isEmpty && prefix.allSatisfy(\.isNumber) && line[dot...].hasPrefix(". ")
    }

    private static func stripNumber(_ line: String) -> String {
        guard let dot = line.firstIndex(of: ".") else { return line }
        return String(line[line.index(dot, offsetBy: 2)...])
    }
}
