import Foundation
import Testing
@testable import SkillHub

struct FrontmatterTests {
    @Test func parsesFlatFields() {
        let doc = Frontmatter.parse("""
        ---
        name: blog-write
        description: "Write a blog post"
        version: '1.2'
        ---

        # Blog Write

        Body here.
        """)
        #expect(doc.name == "blog-write")
        #expect(doc.description == "Write a blog post")
        #expect(doc.version == "1.2")
        #expect(doc.body.hasPrefix("# Blog Write"))
        #expect(doc.body.hasSuffix("Body here."))
    }

    @Test func parsesFoldedAndLiteralBlocks() {
        let doc = Frontmatter.parse("""
        ---
        name: x
        description: >
          First line
          second line
        notes: |
          keep
          lines
        ---
        body
        """)
        #expect(doc.description == "First line second line")
        #expect(doc.body == "body")
    }

    @Test func missingFrontmatterKeepsWholeBody() {
        let doc = Frontmatter.parse("# Just markdown\n\ntext")
        #expect(doc.name.isEmpty)
        #expect(doc.body == "# Just markdown\n\ntext")
    }

    @Test(arguments: [
        ("Blog Write!", "blog-write"),
        ("  --hello--world-- ", "hello-world"),
        ("中文 名字", "中文-名字"),
        ("UPPER_case", "upper-case")
    ])
    func slugifies(input: String, expected: String) {
        #expect(Frontmatter.slug(input) == expected)
    }

    @Test(arguments: ["blog-write", "a1", "x"])
    func acceptsValidNames(name: String) {
        #expect(Frontmatter.isValidSkillName(name))
    }

    @Test(arguments: ["", "-lead", "trail-", "Has Space", "UPPER", String(repeating: "a", count: 65)])
    func rejectsInvalidNames(name: String) {
        #expect(!Frontmatter.isValidSkillName(name))
    }

    @Test func renderRoundTrips() {
        let text = Frontmatter.render(name: "demo-skill", description: "Does demo things", body: "")
        let parsed = Frontmatter.parse(text)
        #expect(parsed.name == "demo-skill")
        #expect(parsed.description == "Does demo things")
        #expect(parsed.body.contains("# Demo Skill"))
    }
}
