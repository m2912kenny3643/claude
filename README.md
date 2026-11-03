# Claude 小精靈 (ClaudeGuide)

macOS 桌面小精靈：你說想做什麼，它看你的螢幕、一次教一步，並在畫面上圈出要點的位置。

## 執行（在你的 Mac 上）
需要 macOS 14+、Xcode 15+ 或 Swift 5.9 工具鏈。

```bash
swift run
```
或 `open Package.swift` 用 Xcode 執行。

1. 第一次啟動輸入 Anthropic API Key（存 Keychain，或設環境變數 `ANTHROPIC_API_KEY`）。
2. 系統設定 → 隱私權與安全性 → **螢幕錄製**，允許終端機（或 Xcode / 打包後的 app）。授權後需重新啟動。
3. 選單列 ✨ 可顯示/隱藏小精靈（⇧⌘G）。

## 運作方式
截圖(ScreenCaptureKit，排除自己的視窗) → Claude 視覺判斷下一步 + 目標座標 → 全螢幕透明 overlay 畫脈動光圈 → 使用者操作後按「下一步」重複。

## 隱私
截圖只在你按「開始/下一步」時送出到 Anthropic API，不會背景持續監看。
