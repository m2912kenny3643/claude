import SwiftUI
import AppKit

@main
struct ClaudeGuideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("Claude 小精靈", systemImage: "sparkles") {
            Button("顯示/隱藏小精靈") { delegate.toggleMascot() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Divider()
            Button("結束") { NSApp.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let session = GuideSession()
    var mascot: MascotPanel!
    var overlay: OverlayWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // 不出現在 Dock
        overlay = OverlayWindow()
        mascot = MascotPanel(session: session)
        session.onTarget = { [weak self] point in self?.overlay.highlight(normalized: point) }
        session.onClear = { [weak self] in self?.overlay.clear() }
        mascot.orderFrontRegardless()
        ScreenCapture.requestAccessIfNeeded()
    }

    func toggleMascot() {
        mascot.isVisible ? mascot.orderOut(nil) : mascot.orderFrontRegardless()
    }
}
