import AppKit
import SwiftUI

/// 全螢幕、透明、滑鼠可穿透的視窗，用來在目標位置畫脈動光圈。
final class OverlayWindow: NSWindow {
    private let model = RingModel()

    init() {
        let frame = NSScreen.main?.frame ?? .zero
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = NSHostingView(rootView: RingView(model: model))
        orderFrontRegardless()
    }

    /// normalized：0–1，左上為原點
    func highlight(normalized p: CGPoint) {
        if let f = NSScreen.main?.frame { setFrame(f, display: true) }
        model.point = p
        model.visible = true
    }

    func clear() { model.visible = false }
}

final class RingModel: ObservableObject {
    @Published var point = CGPoint(x: 0.5, y: 0.5)
    @Published var visible = false
}

struct RingView: View {
    @ObservedObject var model: RingModel
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            if model.visible {
                ZStack {
                    Circle().stroke(Color.claudeOrange, lineWidth: 4)
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulse ? 1.5 : 1).opacity(pulse ? 0.2 : 1)
                    Circle().fill(Color.claudeOrange.opacity(0.25)).frame(width: 40, height: 40)
                }
                .position(x: model.point.x * geo.size.width, y: model.point.y * geo.size.height)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) { pulse = true }
                }
            }
        }
        .ignoresSafeArea()
    }
}
