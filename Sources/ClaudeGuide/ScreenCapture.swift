import AppKit
import ScreenCaptureKit

enum ScreenCapture {
    static func requestAccessIfNeeded() {
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
    }

    /// 截取主螢幕（排除小精靈自己的視窗），回傳縮圖後的 JPEG base64。
    static func captureMainDisplayJPEG(maxWidth: CGFloat = 1568) async throws -> String {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw GuideError.noDisplay }
        let me = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])

        let scale = min(1, maxWidth / CGFloat(display.width))
        let config = SCStreamConfiguration()
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = true

        let cg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw GuideError.encodeFailed
        }
        return jpeg.base64EncodedString()
    }
}

enum GuideError: LocalizedError {
    case noDisplay, encodeFailed, noAPIKey, badResponse(String)
    var errorDescription: String? {
        switch self {
        case .noDisplay: return "找不到螢幕"
        case .encodeFailed: return "截圖編碼失敗"
        case .noAPIKey: return "尚未設定 API Key（選單列 ✨ → 設定 API Key）"
        case .badResponse(let s): return "Claude 回應無法解析：\(s)"
        }
    }
}
