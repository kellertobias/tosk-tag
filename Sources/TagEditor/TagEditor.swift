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
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Tobisk Tag Editor") {
                    AboutWindowController.shared.show()
                }
            }
        }
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

@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }
        
        let contentRect = NSRect(x: 0, y: 0, width: 460, height: 430)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let hostingView = NSHostingView(rootView: AboutWindowContent())
        hostingView.frame = NSRect(origin: .zero, size: contentRect.size)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.title = "About Tobisk Tag Editor"
        window.isReleasedWhenClosed = false
        window.contentMinSize = contentRect.size
        window.contentMaxSize = contentRect.size
        window.center()
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
