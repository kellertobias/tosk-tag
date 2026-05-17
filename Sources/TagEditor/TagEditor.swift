import SwiftUI
import AppKit

@main
struct TagEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app appears in the Dock and app switcher
        NSApplication.shared.setActivationPolicy(.regular)
        // Bring the window to the foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
