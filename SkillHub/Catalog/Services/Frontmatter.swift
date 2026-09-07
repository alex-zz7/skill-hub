import Foundation

/// A deliberately small YAML-frontmatter reader: flat `key: value` pairs plus `|` / `>` block scalars,
/// which is all SKILL.md files use in practice.
nonisolated enum Frontmatter {
    static func parse(_ raw: String) -> FrontmatterDocument {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return FrontmatterDocument(name: "", description: "", version: "", body: normalized, raw: raw)
        }

        var index = 1
        var fields: [String: String] = [:]
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                index += 1
                break
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }
            guard let colon = line.firstIndex(of: ":") else {
                index += 1
                continue
            }

            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

            if ["|", "|-", "|+", ">", ">-"].contains(value) {
                let folded = value.hasPrefix(">")
                index += 1
                var block: [String] = []
                while index < lines.count {
                    let next = lines[index]
                    let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                    if nextTrimmed == "---" { break }
                    let indent = next.prefix { $0 == " " || $0 == "\t" }.count
                    if indent == 0 && !nextTrimmed.isEmpty { break }
                    block.append(String(next.drop(while: { $0 == " " || $0 == "\t" })))
                    index += 1
                }
                fields[key] = folded
                    ? block.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    : block.joined(separator: "\n").trimmingCharacters(in: .newlines)
                continue
            }

            fields[key] = unquote(value)
            index += 1
        }

        let body = lines[index...].joined(separator: "\n").trimmingCharacters(in: .newlines)
        let origin = ["source", "origin", "repository", "repo", "homepage", "url"]
            .compactMap { fields[$0] }
            .first { !$0.isEmpty } ?? ""
        return FrontmatterDocument(
            name: fields["name"] ?? "",
            description: fields["description"] ?? "",
            version: fields["version"] ?? "",
            body: body,
            raw: raw,
            author: fields["author"] ?? fields["maintainer"] ?? "",
            origin: origin
        )
    }

    static func render(name: String, description: String, body: String) -> String {
        let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = content.isEmpty ? "# \(titleCase(safeName))\n\n## Instructions\n" : content
        return """
        ---
        name: \(safeName)
        description: \(safeDescription)
        ---

        \(heading)
        """
    }

    static func slug(_ value: String) -> String {
        let mapped = value.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(mapped)
            .replacing(/-{2,}/, with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(collapsed.prefix(64))
    }

    static func isValidSkillName(_ name: String) -> Bool {
        name.count <= 64 && name.wholeMatch(of: /^[a-z0-9]+(?:-[a-z0-9]+)*$/) != nil
    }

    private static func unquote(_ value: String) -> String {
        if (value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2)
            || (value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func titleCase(_ slug: String) -> String {
        slug.split(separator: "-").map(\.capitalized).joined(separator: " ")
    }
}
