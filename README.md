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

## デプロイ（Xcode Cloud → TestFlight / App Store）

配布用ビルドは [Xcode Cloud](https://developer.apple.com/xcode-cloud/) で行います。
`.xcodeproj` / `Supporting/Info.plist` は XcodeGen の生成物なので、Xcode Cloud には
クローン直後に走るカスタムスクリプト [`ci_scripts/ci_post_clone.sh`](ci_scripts/ci_post_clone.sh)
を用意しています。これが `xcodegen generate` を実行し、ビルド対象のプロジェクトを生成します。

初回セットアップ（App Store Connect / Xcode 側、リポジトリ外の作業）:

1. **Apple Developer Program** に登録（年 99 USD）。
2. **App Store Connect** で App レコードを作成（Bundle ID: `com.example.videocaption.app`）。
   - 本番配布時は `project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を自分の Team の ID に変更する。
3. Xcode の **Product › Xcode Cloud › Create Workflow**、または App Store Connect の
   Xcode Cloud から GitHub リポジトリを接続しワークフローを作成。
   - Scheme: `VideoCaption`（XcodeGen が共有スキームとして生成）
   - Archive アクションで `iOS` / TestFlight への配信先を指定。
4. 署名は **Xcode Cloud の自動署名** に任せる（証明書・プロファイルを Apple が管理）。
   ※ CI 検証用に `CODE_SIGNING_ALLOWED=NO` を設定しているが、Archive ワークフローでは
   Xcode Cloud 側の署名設定が優先される。

以降は対象ブランチへの push で Xcode Cloud が自動ビルド → TestFlight 配信を行います。

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
