import AppKit
import SwiftUI

extension Color {
    /// Claude 品牌橘
    static let claudeOrange = Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255)
}

/// Claude 的星芒標誌（橘色放射線）
struct ClaudeSpark: View {
    var size: CGFloat = 46
    var spinning = false
    @State private var angle = 0.0

    var body: some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let r = min(sz.width, sz.height) / 2 * 0.92
            let lens: [CGFloat] = [1, 0.7, 0.94, 0.76, 1, 0.68, 0.92, 0.78, 1, 0.72, 0.96, 0.7]
            var path = Path()
            for (i, l) in lens.enumerated() {
                let a = Double(i) / Double(lens.count) * 2 * .pi - .pi / 2
                path.move(to: c)
                path.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r * l, y: c.y + CGFloat(sin(a)) * r * l))
            }
            ctx.stroke(path, with: .color(.claudeOrange),
                       style: StrokeStyle(lineWidth: r * 0.2, lineCap: .round))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(angle))
        .onChange(of: spinning) { on in
            if on { withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { angle = 360 } }
            else { withAnimation(.default) { angle = 0 } }
        }
    }
}

final class MascotPanel: NSPanel {
    init(session: GuideSession) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: MascotView(session: session))
        if let s = NSScreen.main {
            setFrameOrigin(NSPoint(x: s.visibleFrame.maxX - 430, y: s.visibleFrame.minY + 20))
        }
    }
    override var canBecomeKey: Bool { true }
}

struct MascotView: View {
    @ObservedObject var session: GuideSession
    @State private var input = ""
    @State private var bob = false
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            VStack(alignment: .leading, spacing: 8) {
                header
                if !session.hasPermission { permissionBanner }
                if session.stepNumber > 0 { Text("第 \(session.stepNumber) 步").font(.caption).foregroundStyle(.secondary) }
                ScrollView { Text(session.message).font(.body).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 110)
                controls
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            ClaudeSpark(size: 46, spinning: session.phase == .thinking)
                .offset(y: bob ? -4 : 4)
                .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { bob.toggle() } }
        }
        .padding(8)
        .onReceive(tick) { _ in session.refreshPermission() }
    }

    // MARK: 標題列：教學對象、模型、更多

    var header: some View {
        HStack(spacing: 6) {
            Menu {
                Button("自動（最近使用的 App）") { session.selectedPID = nil }
                Button("整個螢幕") { session.selectedPID = -1 }
                Divider()
                ForEach(session.apps) { a in Button(a.name) { session.selectedPID = a.pid } }
            } label: { Label(session.targetLabel, systemImage: "macwindow") }
                .menuStyle(.borderlessButton).fixedSize()

            Menu {
                ForEach(GuideSession.models, id: \.id) { m in
                    Button((session.model == m.id ? "✓ " : "") + m.label) { session.model = m.id }
                }
                if !session.usingCLI { Divider(); Text("手動模式：請在 claude.ai 選模型") }
            } label: {
                Label(GuideSession.models.first { $0.id == session.model }?.label ?? "預設", systemImage: "cpu")
            }
            .menuStyle(.borderlessButton).fixedSize().disabled(!session.usingCLI)

            Spacer()

            Menu {
                Button("隱藏小精靈") { session.onHide?() }
                Button("重新啟動") { AppControl.relaunch() }
                Divider()
                Button("結束程式") { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize()
        }
        .font(.caption)
    }

    var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("⚠️ 偵測不到螢幕錄製權限").font(.caption.bold())
            Text("到「系統設定 → 隱私權與安全性 → 螢幕錄製」勾選小精靈後，按「重新啟動」。若已勾選仍無效（更新版本後常見），請先用「−」移除再用「+」重新加入。")
                .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Button("開啟系統設定") { ScreenCapture.openSettings() }
                Button("重新啟動") { AppControl.relaunch() }
            }.font(.caption)
        }
        .padding(8)
        .background(Color.claudeOrange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: 操作區

    @ViewBuilder var controls: some View {
        switch session.phase {
        case .idle, .finished, .failed:
            HStack {
                TextField(session.phase == .idle ? "例如：在 Keynote 新增一頁投影片" : "換個目標…", text: $input)
                    .textFieldStyle(.roundedBorder).onSubmit(go)
                Button("開始", action: go).disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if session.phase == .failed { Button("重試") { session.next() } }
        case .thinking:
            ProgressView().controlSize(.small)
        case .manual:
            HStack {
                if !session.hasSentPrompt { Button("複製提示詞") { session.copyPrompt() } }
                Button("複製截圖") { session.copyScreenshot() }
                Button("貼上回答") { session.pasteReply() }
                Spacer()
                Button("結束") { session.reset() }
            }
            Link("開啟 claude.ai", destination: URL(string: "https://claude.ai/new")!).font(.caption)
        case .showing:
            HStack {
                Button("我做好了，下一步") { session.next() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("卡住了") { session.next(note: "我卡住了或畫面和你說的不一樣，請看畫面再幫我一次。") }
                Spacer()
                Button("結束") { session.reset() }
            }
        }
    }

    private func go() {
        let g = input.trimmingCharacters(in: .whitespaces)
        guard !g.isEmpty else { return }
        input = ""
        session.start(goal: g)
    }
}
