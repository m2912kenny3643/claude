import SwiftUI
import AppKit

@main
struct ClaudeGuideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("Claude 小精靈", systemImage: "sparkles") {
            Button("顯示/隱藏小精靈") { delegate.toggleMascot() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("設定 API Key…") { delegate.promptForAPIKey() }
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
        if APIKeyStore.load() == nil { promptForAPIKey() }
        ScreenCapture.requestAccessIfNeeded()
    }

    func toggleMascot() {
        mascot.isVisible ? mascot.orderOut(nil) : mascot.orderFrontRegardless()
    }

    func promptForAPIKey() {
        let alert = NSAlert()
        alert.messageText = "輸入 Anthropic API Key"
        alert.informativeText = "金鑰只會存在你 Mac 的鑰匙圈 (Keychain)。"
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "儲存")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            APIKeyStore.save(field.stringValue)
        }
    }
}
