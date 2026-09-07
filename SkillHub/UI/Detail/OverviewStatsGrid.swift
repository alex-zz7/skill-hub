import SwiftUI

struct OverviewStatsGrid: View {
    let stats: OverviewStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
            OverviewStatCard(title: "Skills", value: stats.uniqueSkills, symbolName: "square.stack.3d.up")
            OverviewStatCard(title: "Prompts", value: stats.uniquePrompts, symbolName: "text.quote")
            OverviewStatCard(title: String(localized: "重复安装"), value: stats.duplicateSkills, symbolName: "square.on.square")
            OverviewStatCard(title: String(localized: "符号链接"), value: stats.symlinkInstalls, symbolName: "link")
        }
    }
}
