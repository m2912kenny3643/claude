import SwiftUI
import AppKit

@main
struct ClaudeGuideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            Button("顯示/隱藏小精靈") { delegate.toggleMascot() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("開啟螢幕錄製設定") { ScreenCapture.openSettings() }
            Button("重新啟動") { AppControl.relaunch() }
            Divider()
            Button("結束程式") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "sparkle")
        }
    }
}

enum AppControl {
    static func relaunch() {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
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
        session.onHide = { [weak self] in self?.mascot.orderOut(nil) }
        mascot.orderFrontRegardless()
        ScreenCapture.requestAccessIfNeeded()
    }

    func toggleMascot() {
        mascot.isVisible ? mascot.orderOut(nil) : mascot.orderFrontRegardless()
    }
}
