import AppKit
import Testing
@testable import SkillHub

@MainActor
struct AppDelegateTests {
    @Test func lastClosedWindowQuitsTheApp() {
        let delegate = AppDelegate()
        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    @Test func dockReopenIsHandledWhenNoWindowIsVisible() {
        let delegate = AppDelegate()
        #expect(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        #expect(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
    }
}
