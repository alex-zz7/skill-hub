import SwiftUI

struct OverviewStatCard: View {
    let title: String
    let value: Int
    let symbolName: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: symbolName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(value, format: .number)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(Theme.quick, value: value)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
