import SwiftUI

struct SheetRouterView: View {
    let sheet: HubSheet

    var body: some View {
        switch sheet {
        case .newSkill: NewSkillSheet()
        case .newPrompt: NewPromptSheet()
        case .install: InstallSheet()
        case .dedupe: DedupeSheet()
        }
    }
}
