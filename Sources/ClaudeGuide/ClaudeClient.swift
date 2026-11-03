import Foundation

struct GuideStep: Decodable {
    var app: String?
    var instruction: String
    var x: Double?   // 0–1000，左上為原點
    var y: Double?
    var done: Bool
}

enum ClaudeClient {
    static let system = """
    你是「Claude 小精靈」，一位耐心的電腦老師，正在手把手教使用者操作 macOS 上的應用程式。
    使用者會給你目標與目前螢幕截圖。請只給「下一個」最小的動作（一次一步），用繁體中文、
    口語、不用術語。如果需要點擊或操作某個位置，給出該元素中心在截圖中的座標，
    x、y 皆為 0–1000 的比例（左上角 0,0；右下角 1000,1000）。
    若目標需要的應用程式沒開，第一步是教使用者如何開啟（Spotlight：⌘+空白鍵）。
    若畫面和預期不同（跳出對話框、錯誤），先教使用者處理。
    絕不替使用者輸入密碼或個資；遇到付款、刪除等不可逆操作，要先提醒風險。
    只輸出一個 JSON 物件，不要任何其他文字：
    {"app": "目前的應用程式名稱", "instruction": "下一步說明", "x": 數字或null, "y": 數字或null, "done": true或false}
    """

    /// 從 Claude 的回答文字中取出 JSON（容忍前後有多餘文字或 ``` 圍欄）
    static func parse(_ text: String) throws -> GuideStep {
        guard let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}"), s < e,
              let step = try? JSONDecoder().decode(GuideStep.self, from: Data(text[s...e].utf8))
        else { throw GuideError.badResponse(String(text.prefix(300))) }
        return step
    }
}

/// 透過本機已登入的 Claude Code 指令（`claude -p`）提問，使用訂閱額度，不需要 API Key。
enum ClaudeCLI {
    static func locate() async -> Bool {
        let out = try? await shell(["-lc", "command -v claude"])
        return !(out ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func ask(prompt: String, workDir: URL) async throws -> String {
        let raw = try await shell(["-lc", "exec claude \"$@\"", "_",
                                   "-p", prompt, "--output-format", "json",
                                   "--allowedTools", "Read", "--max-turns", "4",
                                   "--append-system-prompt", ClaudeClient.system],
                                  cwd: workDir)
        guard let obj = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
              let result = obj["result"] as? String else { throw GuideError.badResponse(String(raw.prefix(300))) }
        return result
    }

    private static func shell(_ args: [String], cwd: URL? = nil) async throws -> String {
        try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = args
            p.currentDirectoryURL = cwd
            p.standardInput = FileHandle.nullDevice
            let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        }.value
    }
}
