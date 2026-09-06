import SwiftUI

/// Renders `**bold**`, `_italic_`, `` `code` `` and links inside one run of text.
struct InlineMarkdownText: View {
    let text: String

    var body: some View {
        Text(attributed)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
