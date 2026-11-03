import AppKit

@MainActor
final class GuideSession: ObservableObject {
    enum Phase { case idle, thinking, showing, manual, finished, failed }
    private static let idleText = "嗨！告訴我你想做什麼，我來手把手教你 ✨"

    @Published var goal = ""
    @Published var message = GuideSession.idleText
    @Published var phase: Phase = .idle
    @Published var stepNumber = 0
    @Published var usingCLI = false

    var onTarget: ((CGPoint) -> Void)?
    var onClear: (() -> Void)?

    private var log: [String] = []          // 先前每一步的指示（給 CLI 模式當上下文）
    @Published private var manualPromptSent = false
    var hasSentPrompt: Bool { manualPromptSent }
    private var pendingShot: Data?
    private let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClaudeGuide")

    init() {
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        Task { usingCLI = await ClaudeCLI.locate() }
    }

    func start(goal: String) {
        self.goal = goal; log = []; stepNumber = 0; manualPromptSent = false
        Task { await advance(note: "") }
    }

    func next(note: String = "") { Task { await advance(note: note) } }

    func reset() {
        goal = ""; log = []; stepNumber = 0; phase = .idle; manualPromptSent = false
        message = GuideSession.idleText
        onClear?()
    }

    // MARK: - 流程

    private func advance(note: String) async {
        phase = .thinking
        message = "讓我看看你的畫面…"
        onClear?()
        try? await Task.sleep(nanoseconds: 300_000_000)
        do {
            let shot = try await ScreenCapture.captureMainDisplayJPEG()
            if usingCLI {
                let file = workDir.appendingPathComponent("screen.jpg")
                try shot.write(to: file)
                var prompt = "使用者的目標：\(goal)\n"
                if !log.isEmpty { prompt += "你先前已教過的步驟：\n" + log.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n") + "\n" }
                prompt += note.isEmpty ? "使用者說已完成上一步。\n" : "使用者補充：\(note)\n"
                prompt += "請用 Read 讀取目前畫面截圖 screen.jpg，然後依規定只輸出 JSON 給下一步。"
                apply(try ClaudeClient.parse(try await ClaudeCLI.ask(prompt: prompt, workDir: workDir)))
            } else {
                pendingShot = shot
                phase = .manual
                message = manualPromptSent
                    ? "① 按「複製截圖」→ 貼到 claude.ai 同一個對話 ② 等它回答，複製整段回答 ③ 按「貼上回答」"
                    : "第一次：① 按「複製提示詞」貼到 claude.ai 新對話並送出 ② 再按「複製截圖」貼上送出 ③ 複製 Claude 的回答，按「貼上回答」"
            }
        } catch {
            phase = .failed
            message = "糟糕：\(error.localizedDescription)"
        }
    }

    private func apply(_ step: GuideStep) {
        stepNumber += 1
        log.append(step.instruction)
        message = step.instruction
        if step.done { phase = .finished; return }
        phase = .showing
        if let x = step.x, let y = step.y { onTarget?(CGPoint(x: x / 1000, y: y / 1000)) }
    }

    // MARK: - 手動貼上模式

    func copyPrompt() {
        let pb = NSPasteboard.general; pb.clearContents()
        pb.setString("\(ClaudeClient.system)\n\n我的目標：\(goal)\n接下來我會貼上螢幕截圖，請依規定只輸出 JSON。", forType: .string)
        manualPromptSent = true
    }

    func copyScreenshot() {
        guard let d = pendingShot, let img = NSImage(data: d) else { return }
        let pb = NSPasteboard.general; pb.clearContents(); pb.writeObjects([img])
    }

    func pasteReply() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            message = "剪貼簿裡沒有文字，請先複製 Claude 的回答。"; return
        }
        do { apply(try ClaudeClient.parse(text)) }
        catch { message = "看不懂這段回答，請確認複製的是 Claude 回的 JSON。" }
    }
}
