import Foundation

struct GuideStep: Decodable {
    var app: String?          // 目前畫面上的應用程式
    var instruction: String   // 白話的下一步說明
    var x: Double?            // 目標位置，0–1000，左上為原點
    var y: Double?
    var done: Bool            // 目標是否已完成
}

struct ClaudeClient {
    static let model = "claude-sonnet-5-5"

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

    /// history：先前每輪的文字（使用者回報 + 你的指示），只有最新一輪附截圖。
    static func nextStep(goal: String, history: [(role: String, text: String)],
                         screenshotBase64: String, userNote: String) async throws -> GuideStep {
        guard let key = APIKeyStore.load() else { throw GuideError.noAPIKey }

        var messages: [[String: Any]] = [["role": "user", "content": "我的目標：\(goal)"]]
        for h in history { messages.append(["role": h.role, "content": h.text]) }
        // 合併連續同角色訊息，避免 API 拒絕
        messages = merge(messages)
        let latest: [[String: Any]] = [
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": screenshotBase64]],
            ["type": "text", "text": userNote.isEmpty ? "這是我現在的畫面，請告訴我下一步。" : userNote]
        ]
        if messages.last?["role"] as? String == "user" {
            var last = messages.removeLast()
            let prev = last["content"] as? String ?? ""
            last["content"] = [["type": "text", "text": prev]] + latest
            messages.append(last)
        } else {
            messages.append(["role": "user", "content": latest])
        }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "max_tokens": 600, "system": system, "messages": messages
        ])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw GuideError.badResponse(String(data: data, encoding: .utf8) ?? "HTTP error")
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = root["content"] as? [[String: Any]],
              let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}")
        else { throw GuideError.badResponse(String(data: data, encoding: .utf8) ?? "") }
        do {
            return try JSONDecoder().decode(GuideStep.self, from: Data(text[s...e].utf8))
        } catch {
            throw GuideError.badResponse(text)
        }
    }

    private static func merge(_ msgs: [[String: Any]]) -> [[String: Any]] {
        var out: [[String: Any]] = []
        for m in msgs {
            if let last = out.last, last["role"] as? String == m["role"] as? String,
               let a = last["content"] as? String, let b = m["content"] as? String {
                out[out.count - 1]["content"] = a + "\n" + b
            } else { out.append(m) }
        }
        return out
    }
}
