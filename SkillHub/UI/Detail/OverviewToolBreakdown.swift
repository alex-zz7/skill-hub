import SwiftUI

struct OverviewToolBreakdown: View {
    let stats: OverviewStats

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ToolSource.skillRoots, id: \.self) { source in
                    LabeledContent {
                        Text(stats.byTool[source, default: 0], format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } label: {
                        Label {
                            Text(source.title)
                        } icon: {
                            Image(systemName: source.symbolName)
                                .foregroundStyle(source.tint)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("按工具", systemImage: "wrench.and.screwdriver")
        }
    }
}
