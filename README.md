# RunVoiceGuide (iOS / SwiftUI)

単一コースのランニング音声ガイド。5 秒周期で位置ログ、ガイド到達で自動再生、スタート地点回帰で自動終了。  
Recording はマイク録音のみ（ファイル選択なし）。音源+配置 JSON の入出力、コース書き出しに対応。

## Requirements

-   macOS (Apple Silicon 推奨)
-   Xcode 15 以上
-   iOS 15 以上の実機（バックグラウンド検証のため実機推奨）

## Getting Started

### 1) Clone

```bash
git clone https://github.com/<YOUR_ORG_OR_USER>/run_voice_guide.git
cd run_voice_guide
```

### 2) Open in Xcode

-   `RunVoiceGuide.xcodeproj` を開く
-   Xcode メニュー: **File > Packages > Reset Package Caches**（SPM 依存がある場合の安定化）
-   初回は自動でパッケージ解決が走ります

### 3) Signing（実機で動かす場合）

1. Xcode 左の Navigator で **RunVoiceGuide** ターゲットを選択
2. **Signing & Capabilities** タブ → **Team** に自分の Apple ID を選択
3. Bundle Identifier は各自ユニークに（例：`com.yourname.runvoiceguide`）

### 4) Capabilities / Info.plist（すでに設定済みのはず）

-   Capabilities:

    -   ✅ **Background Modes** → _Location updates_, _Audio, AirPlay, and Picture in Picture_

-   Info.plist:

    -   `NSLocationWhenInUseUsageDescription`
    -   `NSLocationAlwaysAndWhenInUseUsageDescription`
    -   `NSMicrophoneUsageDescription`
    -   `UIBackgroundModes` = `location`, `audio`

### 5) Run（実機）

-   iPhone を **ケーブル接続** → 端末側で「このコンピュータを信頼」
-   iOS 16+ の場合：設定 > プライバシーとセキュリティ > **デベロッパモード** を ON（再起動あり）
-   Xcode 上部デバイス選択で自分の iPhone を選び **Run ▶**
-   初回起動時に位置/マイク許可を「許可」
-   （任意）Wi-Fi デバッグ：Xcode **Window > Devices and Simulators** → 端末を選択 → **Connect via network** を ON

    -   初回は有線でペアリングしてからにしてください
