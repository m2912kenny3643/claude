import Foundation

@MainActor
final class GuideSession: ObservableObject {
    enum Phase { case idle, thinking, showing, finished, failed }

    @Published var goal = ""
    @Published var message = "嗨！告訴我你想做什麼，我來手把手教你 ✨"
    @Published var phase: Phase = .idle
    @Published var stepNumber = 0

    var onTarget: ((CGPoint) -> Void)?
    var onClear: (() -> Void)?
    private var history: [(role: String, text: String)] = []

    func start(goal: String) {
        self.goal = goal
        history = []
        stepNumber = 0
        Task { await advance(note: "") }
    }

    /// 使用者做完這一步（或想補充狀況）
    func next(note: String = "") {
        Task { await advance(note: note) }
    }

    func reset() {
        goal = ""; history = []; stepNumber = 0; phase = .idle
        message = "嗨！告訴我你想做什麼，我來手把手教你 ✨"
        onClear?()
    }

    private func advance(note: String) async {
        phase = .thinking
        message = "讓我看看你的畫面…"
        onClear?()
        try? await Task.sleep(nanoseconds: 300_000_000) // 等圈圈消失
        do {
            let shot = try await ScreenCapture.captureMainDisplayJPEG()
            let step = try await ClaudeClient.nextStep(goal: goal, history: history,
                                                       screenshotBase64: shot, userNote: note)
            stepNumber += 1
            history.append((role: "user", text: note.isEmpty ? "（已完成上一步，畫面如最新截圖）" : note))
            history.append((role: "assistant", text: step.instruction))
            message = step.instruction
            if step.done { phase = .finished; return }
            phase = .showing
            if let x = step.x, let y = step.y { onTarget?(CGPoint(x: x / 1000, y: y / 1000)) }
        } catch {
            phase = .failed
            message = "糟糕：\(error.localizedDescription)"
        }
    }
}
