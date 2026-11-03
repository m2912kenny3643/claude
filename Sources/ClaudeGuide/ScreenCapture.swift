import AppKit
import CoreGraphics

enum ScreenCapture {
    static func requestAccessIfNeeded() {
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
    }

    /// 截取主螢幕（排除小精靈自己的視窗），回傳縮圖後的 JPEG base64。相容 macOS 13。
    static func captureMainDisplayJPEG(maxWidth: CGFloat = 1568) async throws -> String {
        let myPID = ProcessInfo.processInfo.processIdentifier
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { throw GuideError.noDisplay }
        let ids: [CGWindowID] = info.compactMap { w in
            guard (w[kCGWindowOwnerPID as String] as? Int32) != myPID,
                  let n = w[kCGWindowNumber as String] as? UInt32 else { return nil }
            return n
        }
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let arr = ids.map { NSNumber(value: $0) } as CFArray
        guard let cg = CGImage(windowListFromArrayScreenBounds: bounds, windowArray: arr,
                               imageOption: [.bestResolution]) else { throw GuideError.noDisplay }

        // 縮小到 maxWidth
        let scale = min(1, maxWidth / CGFloat(cg.width))
        let w = Int(CGFloat(cg.width) * scale), h = Int(CGFloat(cg.height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw GuideError.encodeFailed }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let scaled = ctx.makeImage(),
              let jpeg = NSBitmapImageRep(cgImage: scaled)
                .representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else { throw GuideError.encodeFailed }
        return jpeg.base64EncodedString()
    }
}

enum GuideError: LocalizedError {
    case noDisplay, encodeFailed, noAPIKey, badResponse(String)
    var errorDescription: String? {
        switch self {
        case .noDisplay: return "找不到螢幕（請確認已授權螢幕錄製）"
        case .encodeFailed: return "截圖編碼失敗"
        case .noAPIKey: return "尚未設定 API Key（選單列 ✨ → 設定 API Key）"
        case .badResponse(let s): return "Claude 回應無法解析：\(s)"
        }
    }
}
