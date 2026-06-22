# 仕様書（軽め）— モードA：動画字幕焼き込み

> A・B・C を1アプリに統合する構想の第一弾。本書は A（字幕焼き込み）の MVP 仕様。
> 凡例: **確定** = 会話で合意済み / `[要確認]` = 提案段階で未確定 / `[TBD]` = 未定

## 概要
動画を入れると音声認識で字幕を作り、焼き込んで書き出すツール。

## 満たすべき条件（確定）
- 単機能で用途が明確
- グローバルで刺さる
- iPhone単体で動く
- AI機能（音声認識）を含む

## ユーザーフロー
1. 動画を入れる
2. 音声認識で字幕を生成
3. スタイル（プリセット）を選んで焼き込み
4. 書き出し

## 用途・ターゲット（確定）
- SNS向け（TikTok / Reels / Shorts）の**同言語字幕**に特化
- 汎用用途は当面スコープ外

## スコープ（確定）
| 項目 | 方針 |
|---|---|
| 出力 | **焼き込み動画のみ**。SRT 等の字幕ファイル書き出しはしない |
| 字幕編集 | 生成字幕の手動編集は **MVP では非対応** |
| スタイル | **プリセットを複数用意**（カスタム編集は MVP 外） |
| 収益化 | **買い切り（インストール課金 / 有料アプリ）**。サブスク・広告は当面なし |

## 技術（確定）
- プラットフォーム：**iOS のみ**（Android はスコープ外）
- 言語 / UI：**Swift + SwiftUI**
- 音声認識：**Apple Speech（オンデバイス）**
  - iOS 26+：`SpeechAnalyzer` + `SpeechTranscriber`（長尺・ワード単位タイミング）
  - 下位互換：`SFSpeechRecognizer`（`requiresOnDeviceRecognition = true`）にフォールバック
- 動画処理：**AVFoundation**（`AVMutableVideoComposition` + Core Animation レイヤで焼き込み、`AVAssetExportSession` で書き出し）
- サーバー課金ゼロ・**端末内完結**

### 処理パイプライン
```
動画入力 (AVAsset)
  └─ 音声トラック抽出
       └─ オンデバイス文字起こし → テキスト + タイムスタンプ
            └─ プリセット適用（フォント / 色 / 位置）
                 └─ AVMutableVideoComposition + Core Animation で焼き込み
                      └─ AVAssetExportSession で書き出し
```

## 実装 / CI（確定）
- 最低OS：**iOS 17.0**（`SpeechAnalyzer` 利用時は iOS 26+、それ未満は `SFSpeechRecognizer` にフォールバック）
- プロジェクト生成：**XcodeGen**（`project.yml` をコミットし、`.xcodeproj` は生成物として gitignore）
- CI：**GitHub Actions（macOS ランナー）** で `xcodegen generate` → `xcodebuild build-for-testing`（アプリ＋テストのコンパイルをゲート）
- MVP プリセット：**4種**（Clean / Bold / Boxed / Top）。アニメは表示・非表示のフェードのみ

## 未定事項（TBD）
| # | 項目 | 内容 |
|---|---|---|
| 1 | 対応言語 | MVP は端末ロケール（`Locale.current`）に追従。言語選択UIは後続 |
| 2 | スタイル拡張 | プリセット追加・カスタム編集（色 / 位置 / アニメ）は後続 |
| 3 | 動画長・解像度 | 想定する最大動画尺・解像度の上限 |
| 4 | 価格 | 買い切りの価格設定 |
| 5 | アプリ名 | 仮称 "Caption"（未確定） |

## 確定済み質問（記録）
1. ターゲットは SNS特化か汎用か → **SNS特化**
2. 出力は焼き込みのみか、SRT も出すか → **焼き込み特化**
3. 手動編集機能を MVP に入れるか → **入れない**
4. 字幕スタイルの作り込み → **プリセットを複数**
5. 収益化方針 → **インストール課金（買い切り）**
