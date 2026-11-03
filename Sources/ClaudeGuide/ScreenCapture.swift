import AppKit
import CoreGraphics

struct Capture {
    let jpeg: Data
    let rect: CGRect   // 截圖範圍，全域座標（左上角為原點，單位 pt）
}

enum CaptureTarget { case screen, app(pid_t) }

enum ScreenCapture {
    static var hasAccess: Bool { CGPreflightScreenCaptureAccess() }

    static func requestAccessIfNeeded() {
        if !hasAccess { CGRequestScreenCaptureAccess() }
    }

    static func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    /// 只截取目標 App 的視窗（加上選單列），其他 App 的內容不會出現在截圖裡。
    static func capture(_ target: CaptureTarget, appName: String, maxWidth: CGFloat = 1568) throws -> Capture {
        guard hasAccess else { throw GuideError.noPermission }
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { throw GuideError.noWindow(appName) }
        let display = CGDisplayBounds(CGMainDisplayID())
        let myPID = ProcessInfo.processInfo.processIdentifier

        var ids: [CGWindowID] = []
        var rect = CGRect.null
        var appWindows = 0
        for w in info {
            guard let num = w[kCGWindowNumber as String] as? UInt32,
                  let owner = w[kCGWindowOwnerPID as String] as? Int32,
                  let bd = w[kCGWindowBounds as String] as? [String: Any],
                  let b = CGRect(dictionaryRepresentation: bd as CFDictionary),
                  b.width > 1, b.height > 1,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { continue }
            switch target {
            case .screen:
                guard owner != myPID else { continue }
                ids.append(num); rect = rect.union(b); appWindows += 1
            case .app(let pid):
                let isMenuBar = (w[kCGWindowOwnerName as String] as? String) == "Window Server"
                    && (w[kCGWindowName as String] as? String) == "Menubar"
                if owner == pid { appWindows += 1 }
                guard owner == pid || isMenuBar else { continue }
                ids.append(num); rect = rect.union(b)
            }
        }
        if case .screen = target { rect = display }
        rect = rect.intersection(display)
        guard appWindows > 0, !rect.isNull, rect.width > 1, rect.height > 1 else { throw GuideError.noWindow(appName) }

        guard let cg = CGImage(windowListFromArrayScreenBounds: rect, windowArray: ids as CFArray,
                               imageOption: [.bestResolution]) else { throw GuideError.noWindow(appName) }

        let scale = min(1, maxWidth / CGFloat(cg.width))
        let w = Int(CGFloat(cg.width) * scale), h = Int(CGFloat(cg.height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw GuideError.encodeFailed }
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))           // 透明處（其他 App）填灰色
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let scaled = ctx.makeImage(),
              let jpeg = NSBitmapImageRep(cgImage: scaled)
                .representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else { throw GuideError.encodeFailed }
        return Capture(jpeg: jpeg, rect: rect)
    }
}

enum GuideError: LocalizedError {
    case noPermission, noWindow(String), encodeFailed, badResponse(String)
    var errorDescription: String? {
        switch self {
        case .noPermission:
            return "還沒有螢幕錄製權限。請按下方「開啟系統設定」勾選小精靈，然後按「重新啟動」。"
        case .noWindow(let n):
            return "看不到「\(n)」的視窗。請先打開它並讓視窗顯示在畫面上（不要最小化），或在上方改選「整個螢幕」。"
        case .encodeFailed: return "截圖編碼失敗"
        case .badResponse(let s): return "Claude 回應無法解析：\(s)"
        }
    }
}
