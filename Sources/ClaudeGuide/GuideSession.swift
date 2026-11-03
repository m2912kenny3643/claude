import AppKit

struct AppChoice: Identifiable, Hashable {
    let pid: pid_t
    let name: String
    var id: pid_t { pid }
}

@MainActor
final class GuideSession: ObservableObject {
    enum Phase { case idle, thinking, showing, manual, finished, failed }
    private static let idleText = "嗨！告訴我你想學哪個 App 的什麼操作，我來手把手教你 ✨"
    static let models: [(id: String, label: String)] =
        [("default", "預設"), ("sonnet", "Sonnet"), ("opus", "Opus"), ("haiku", "Haiku"), ("fable", "Fable")]

    @Published var goal = ""
    @Published var message = GuideSession.idleText
    @Published var phase: Phase = .idle
    @Published var stepNumber = 0
    @Published var usingCLI = false
    @Published var hasPermission = ScreenCapture.hasAccess
    @Published var apps: [AppChoice] = []
    /// nil = 自動（最近使用的 App）；-1 = 整個螢幕；其他 = 指定 App 的 pid
    @Published var selectedPID: pid_t? = nil
    @Published var model: String = UserDefaults.standard.string(forKey: "model") ?? "default" {
        didSet { UserDefaults.standard.set(model, forKey: "model") }
    }
    @Published private var manualPromptSent = false
    var hasSentPrompt: Bool { manualPromptSent }

    var onTarget: ((CGPoint) -> Void)?
    var onClear: (() -> Void)?
    var onHide: (() -> Void)?

    private var log: [String] = []
    private var pendingShot: Data?
    private var lastRect = CGRect.zero
    private var currentAppName = ""
    private var lastFront: NSRunningApplication?
    private let myPID = ProcessInfo.processInfo.processIdentifier
    private let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("ClaudeGuide")

    init() {
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        Task { usingCLI = await ClaudeCLI.locate() }
        lastFront = NSWorkspace.shared.frontmostApplication.flatMap { $0.processIdentifier == myPID ? nil : $0 }
        refreshApps()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let activated = note.name == NSWorkspace.didActivateApplicationNotification
                Task { @MainActor in self?.workspaceChanged(app, activated: activated) }
            }
        }
    }

    private func workspaceChanged(_ app: NSRunningApplication?, activated: Bool) {
        if activated, let app, app.processIdentifier != myPID, app.activationPolicy == .regular { lastFront = app }
        refreshApps()
    }

    private func refreshApps() {
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != myPID }
            .map { AppChoice(pid: $0.processIdentifier, name: $0.localizedName ?? "App") }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func refreshPermission() { hasPermission = ScreenCapture.hasAccess }

    private var target: (CaptureTarget, String)? {
        if selectedPID == -1 { return (.screen, "整個螢幕") }
        if let pid = selectedPID, let app = NSRunningApplication(processIdentifier: pid) {
            return (.app(pid), app.localizedName ?? "App")
        }
        if let app = lastFront, !app.isTerminated { return (.app(app.processIdentifier), app.localizedName ?? "App") }
        return nil
    }

    var targetLabel: String {
        if selectedPID == nil { return "自動：" + (lastFront?.localizedName ?? "未偵測") }
        return target?.1 ?? "未選擇"
    }

    // MARK: - 流程

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

    private func advance(note: String) async {
        refreshPermission()
        phase = .thinking
        message = "讓我看看「\(target?.1 ?? "畫面")」…"
        onClear?()
        try? await Task.sleep(nanoseconds: 300_000_000) // 等光圈消失再截圖
        do {
            guard let (t, name) = target else { throw GuideError.noWindow("目標 App") }
            currentAppName = name
            let cap = try ScreenCapture.capture(t, appName: name)
            lastRect = cap.rect
            if usingCLI {
                let file = workDir.appendingPathComponent("screen.jpg")
                try cap.jpeg.write(to: file)
                var prompt = "使用者的目標：\(goal)\n目標應用程式：\(name)（截圖只含它的視窗與選單列）\n"
                if !log.isEmpty { prompt += "你先前已教過的步驟：\n" + log.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n") + "\n" }
                prompt += note.isEmpty ? "使用者說已完成上一步。\n" : "使用者補充：\(note)\n"
                prompt += "請用 Read 讀取目前畫面截圖 screen.jpg，然後依規定只輸出 JSON 給下一步。"
                apply(try ClaudeClient.parse(try await ClaudeCLI.ask(prompt: prompt, workDir: workDir, model: model)))
            } else {
                pendingShot = cap.jpeg
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
        if let x = step.x, let y = step.y, lastRect.width > 0 {
            // 截圖內的比例 → 全域座標 → 主螢幕比例
            let d = CGDisplayBounds(CGMainDisplayID())
            let gx = lastRect.minX + CGFloat(x) / 1000 * lastRect.width
            let gy = lastRect.minY + CGFloat(y) / 1000 * lastRect.height
            onTarget?(CGPoint(x: (gx - d.minX) / d.width, y: (gy - d.minY) / d.height))
        }
    }

    // MARK: - 手動貼上模式

    func copyPrompt() {
        let pb = NSPasteboard.general; pb.clearContents()
        pb.setString("\(ClaudeClient.system)\n\n我的目標：\(goal)\n目標應用程式：\(currentAppName)\n接下來我會貼上截圖，請依規定只輸出 JSON。", forType: .string)
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
