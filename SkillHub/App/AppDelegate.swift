import AppKit

/// Guideline 4: closing the only window used to leave the app running with no way
/// to get the window back. Quit instead — this is a single-window utility.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        if let window = sender.windows.first(where: \.canBecomeMain) ?? sender.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
