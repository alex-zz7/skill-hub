import Foundation
import Testing
@testable import SkillHub

struct ClusterGroupingTests {
    @Test func tokensSplitOnDashUnderscoreAndSpace() {
        #expect(ClusterGrouping.tokens("Blog_Write seo-Audit") == ["blog", "write", "seo", "audit"])
    }

    @Test func nextPrefixDescendsOneLevel() {
        #expect(ClusterGrouping.nextPrefix(of: "blog-seo-audit", deeperThan: nil) == "blog")
        #expect(ClusterGrouping.nextPrefix(of: "blog-seo-audit", deeperThan: "blog") == "blog-seo")
        #expect(ClusterGrouping.nextPrefix(of: "blog-seo-audit", deeperThan: "blog-seo") == nil)
        #expect(ClusterGrouping.nextPrefix(of: "single", deeperThan: nil) == nil)
    }

    @Test func belongsMatchesWholeTokensOnly() {
        #expect(ClusterGrouping.belongs(name: "blog-write", prefix: "blog"))
        #expect(ClusterGrouping.belongs(name: "blog", prefix: "blog"))
        #expect(!ClusterGrouping.belongs(name: "blogger-tool", prefix: "blog"))
    }

    @Test func builderGroupsSiblingsAndLeavesSingletonsLoose() {
        let items = [
            ClusterBuilder.Item(id: "1", title: "blog-write", weight: 10, openCount: 3, isSkill: true),
            ClusterBuilder.Item(id: "2", title: "blog-audit", weight: 5, openCount: 1, isSkill: true),
            ClusterBuilder.Item(id: "3", title: "blog", weight: 2, openCount: 0, isSkill: true),
            ClusterBuilder.Item(id: "4", title: "seo-plan", weight: 7, openCount: 2, isSkill: true),
            ClusterBuilder.Item(id: "5", title: "lonely", weight: 1, openCount: 0, isSkill: false)
        ]
        let nodes = ClusterBuilder.nodes(from: items, parent: nil, looseCap: nil)

        let blog = nodes.first { $0.title == "blog" }
        #expect(blog?.isGroup == true)
        #expect(blog?.count == 3)
        #expect(blog?.openCount == 4)
        #expect(Set(blog?.memberIDs ?? []) == ["1", "2", "3"])

        // seo-plan has no sibling, so it must not become a group of one.
        #expect(nodes.first { $0.title == "seo-plan" }?.isGroup == false)
        #expect(nodes.first { $0.title == "lonely" }?.kind == .prompt("5"))
        #expect(nodes.count == 3)
    }

    @Test func looseCapLimitsSingletons() {
        let items = (0..<10).map {
            ClusterBuilder.Item(id: "\($0)", title: "item\($0)", weight: Double($0), openCount: 0, isSkill: true)
        }
        let nodes = ClusterBuilder.nodes(from: items, parent: nil, looseCap: 3)
        #expect(nodes.count == 3)
        #expect(nodes.first?.title == "item9")
    }

    @Test func narrowCanvasKeepsHeaviestNodesAndSizesThemLargest() {
        let nodes = (0..<30).map {
            ClusterNode(id: "n\($0)", title: "node \($0)", kind: .skill("n\($0)"), weight: Double(1 + $0 * 4), count: 1, openCount: 0)
        }
        let placements = ClusterLayout.plan(nodes: nodes, canvas: CGSize(width: 320, height: 360))
        let heaviest = try? #require(placements["n29"])
        let lightest = placements["n0"]
        #expect(heaviest != nil, "the heaviest node must always be placed")
        if let heaviest, let lightest {
            #expect(heaviest.diameter >= lightest.diameter)
        }
    }

    @Test func layoutPlacesEveryNodeWithoutOverlap() {
        let nodes = (0..<12).map {
            ClusterNode(id: "n\($0)", title: "node \($0)", kind: .skill("n\($0)"), weight: Double(1 + $0 * 3), count: 1, openCount: 0)
        }
        let canvas = CGSize(width: 900, height: 700)
        let placements = ClusterLayout.plan(nodes: nodes, canvas: canvas)
        #expect(placements.count == nodes.count)

        let values = Array(placements.values)
        for i in values.indices {
            for j in values.indices where j > i {
                let a = values[i]
                let b = values[j]
                let distance = hypot(a.center.x - b.center.x, a.center.y - b.center.y)
                #expect(distance + 0.5 >= (a.diameter + b.diameter) / 2, "bubbles \(i) and \(j) overlap")
            }
        }
    }
}
