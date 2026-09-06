import Foundation
import Testing
@testable import SkillHub

struct MarkdownParserTests {
    @Test func splitsCommonBlocks() {
        let blocks = MarkdownParser.blocks(from: """
        ---
        name: demo
        ---
        # Title

        A paragraph that
        wraps lines.

        - one
        - two

        1. first
        2. second

        ```swift
        let x = 1
        ```

        > quoted

        ---

        | a | b |
        |---|---|
        | 1 | 2 |
        """)

        #expect(blocks.count == 8)
        #expect(blocks[0] == .heading(1, "Title"))
        #expect(blocks[1] == .paragraph("A paragraph that wraps lines."))
        #expect(blocks[2] == .bullets(["one", "two"]))
        #expect(blocks[3] == .numbered(["first", "second"]))
        #expect(blocks[4] == .code("let x = 1"))
        #expect(blocks[5] == .quote("quoted"))
        #expect(blocks[6] == .rule)
        #expect(blocks[7] == .table(["a", "b"], [["1", "2"]]))
    }

    @Test func dropsHeadingThatRepeatsTitle() {
        let blocks: [MarkdownBlock] = [.heading(1, "Blog Write"), .paragraph("x")]
        #expect(MarkdownParser.skippingRedundantTitle(blocks, title: "blog-write") == [.paragraph("x")])
        #expect(MarkdownParser.skippingRedundantTitle(blocks, title: "other") == blocks)
    }

    @Test func hashWithoutSpaceIsNotHeading() {
        let blocks = MarkdownParser.blocks(from: "#hashtag text")
        #expect(blocks == [.paragraph("#hashtag text")])
    }
}
