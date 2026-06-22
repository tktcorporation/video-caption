# video-caption

動画にオンデバイス音声認識で字幕を生成し、選んだスタイルで焼き込んで書き出す iOS アプリ（モードA）。
仕様は [`docs/spec-mode-a.md`](docs/spec-mode-a.md)。

## 特徴（MVP）
- 端末内で完結（サーバー課金ゼロ）のオンデバイス音声認識
- SNS（TikTok / Reels / Shorts）向けの同言語字幕に特化
- 字幕プリセット4種（Clean / Bold / Boxed / Top）を選んで焼き込み
- 焼き込み動画を書き出して共有

## 技術
- Swift + SwiftUI（iOS 17.0+）
- 音声認識：Apple Speech（`SFSpeechRecognizer`、オンデバイス）
- 動画処理：AVFoundation + Core Animation で焼き込み・書き出し

## 開発

Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で `project.yml` から生成します。

```sh
brew install xcodegen
xcodegen generate
open VideoCaption.xcodeproj
```

### ビルド / テスト（CI と同じ）

```sh
xcodebuild build-for-testing \
  -project VideoCaption.xcodeproj \
  -scheme VideoCaption \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

CI は GitHub Actions（macOS ランナー）で上記のビルド＝アプリとテストのコンパイルを実行します。
`.xcodeproj` は生成物のため Git 管理対象外です。

## ディレクトリ構成
```
Sources/
  App/         アプリのエントリポイント
  Models/      データモデル / スタイル定義
  Services/    音声認識・字幕焼き込み
  ViewModels/  画面の状態管理
  Views/       SwiftUI 画面
Tests/         ユニットテスト
docs/          仕様書
```
