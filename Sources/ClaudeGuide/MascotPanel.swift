import AppKit
import SwiftUI

final class MascotPanel: NSPanel {
    init(session: GuideSession) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 340, height: 260),
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
            setFrameOrigin(NSPoint(x: s.visibleFrame.maxX - 370, y: s.visibleFrame.minY + 20))
        }
    }
    override var canBecomeKey: Bool { true } // 讓輸入框可以打字
}

struct MascotView: View {
    @ObservedObject var session: GuideSession
    @State private var input = ""
    @State private var bob = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            VStack(alignment: .leading, spacing: 8) {
                if session.stepNumber > 0 { Text("第 \(session.stepNumber) 步").font(.caption).foregroundStyle(.secondary) }
                ScrollView { Text(session.message).font(.body).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 110)
                controls
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            Text(session.phase == .thinking ? "🧚‍♀️💭" : "🧚‍♀️")
                .font(.system(size: 44))
                .offset(y: bob ? -4 : 4)
                .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { bob.toggle() } }
        }
        .padding(8)
    }

    @ViewBuilder var controls: some View {
        switch session.phase {
        case .idle, .finished, .failed:
            HStack {
                TextField(session.phase == .idle ? "例如：用 Keynote 做簡報" : "換個目標…", text: $input)
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
