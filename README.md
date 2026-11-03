# Claude 小精靈 (ClaudeGuide)

macOS 桌面小精靈：你說想做什麼，它看你的螢幕、一次教一步，並在畫面上圈出要點的位置。

## 執行（在你的 Mac 上）
不需要 API Key。需要 macOS 13+（Intel 或 Apple Silicon）。

- **自動模式**：Mac 上有安裝並登入 Claude Code（終端機輸入 `claude` 可用），小精靈會用你的 Claude 訂閱額度。
- **手動模式**：沒有 `claude` 指令時，按「複製提示詞 / 複製截圖」貼到 claude.ai，再按「貼上回答」。

系統設定 → 隱私權與安全性 → **螢幕錄製** 要允許小精靈，授權後按小精靈上的「重新啟動」。
更新到新版後如果授權失效（App 沒有正式簽章，macOS 會視為新 App），先用「−」移除舊的再「+」加入；或在終端機執行 `tccutil reset ScreenCapture com.example.ClaudeGuide` 後重新授權。

小精靈只會截取你選定的那個 App 的視窗（加選單列），其他 App 的內容不會被送出；可在面板上方切換教學對象與模型。選單列 ✨ 可顯示/隱藏（⇧⌘G）。

## 運作方式
截圖(排除自己的視窗) → Claude 視覺判斷下一步 + 目標座標 → 全螢幕透明 overlay 畫脈動光圈 → 使用者操作後按「下一步」重複。

## 隱私
截圖只在你按「開始/下一步」時送出，不會背景持續監看。

## 用 GitHub Actions 雲端編譯（Intel Mac / macOS 13）
推送後到 repo 的 Actions 頁籤 → 最新的 “Build macOS app” → 下載 `ClaudeGuide-intel` 。解壓後：

```bash
xattr -cr ClaudeGuide.app   # 移除下載隔離標記（未經 Apple 簽章）
open ClaudeGuide.app
```
第一次開啟如被擋，右鍵 → 打開。每次換新版本都需要在「螢幕錄製」重新允許。
