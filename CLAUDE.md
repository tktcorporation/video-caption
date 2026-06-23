# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An iOS app (Swift + SwiftUI, iOS 17.0+) that generates subtitles from a video
using **on-device** speech recognition, burns the chosen caption style into the
video, and exports the result for sharing. Everything runs on-device — there is
no backend. Full product spec: `docs/spec-mode-a.md`. UI strings and error
messages are in Japanese.

## Project generation & build

The `.xcodeproj` is **not** committed — it is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen). After cloning, after editing
`project.yml`, or after adding/removing source files, regenerate it:

```sh
brew install xcodegen   # once
xcodegen generate
open VideoCaption.xcodeproj
```

Build the app + compile tests exactly as CI does (`.github/workflows/ci.yml`,
macOS runner):

```sh
xcodebuild build-for-testing \
  -project VideoCaption.xcodeproj \
  -scheme VideoCaption \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

CI only builds and compiles tests — it does **not** run them (it uses
`generic/platform=iOS Simulator`, with no booted simulator). To actually run
tests locally, target a concrete simulator:

```sh
xcodebuild test \
  -project VideoCaption.xcodeproj \
  -scheme VideoCaption \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# single test
xcodebuild test ... -only-testing:VideoCaptionTests/CaptionGroupingTests/testSplitsOnMaxWords
```

## Architecture

The pipeline is **pick → transcribe → group → burn → export**, orchestrated by
`CaptionViewModel` (the single `ObservableObject` driving `ContentView`).

- **`MovieFile`** (Models) — `Transferable` that copies a `PhotosPickerItem`
  into the temp directory so the file outlives the picker's sandboxed delivery.
- **`TranscriptionService`** (Services, `@MainActor`) — extracts the audio
  track to a temp m4a (`SFSpeechURLRecognitionRequest` needs an audio file, not
  a video container), then runs `SFSpeechRecognizer` with
  `requiresOnDeviceRecognition = true`. Unavailable on-device recognition
  throws rather than falling back to the network.
- **Word grouping** — `TranscriptionService.group(words:maxWords:maxGap:)` is a
  `nonisolated static` pure function that turns timed words into caption-sized
  lines (new line after `maxWords` words or a silence gap > `maxGap`). It takes
  the framework-agnostic `TimedWord` struct specifically so it can be unit
  tested without the Speech framework — this is the main tested logic. Keep it
  pure and Speech-free.
- **`CaptionBurner`** (Services) — composites captions with AVFoundation +
  Core Animation (`AVVideoCompositionCoreAnimationTool`) and exports an mp4.
  Two coordinate/timing subtleties live here: the animation tool renders in a
  **bottom-left origin** system (so `verticalPosition`, which is measured from
  the top, is flipped), and it reads each track's own `timeRange` / start
  rather than assuming the track spans `asset.duration`, so trimmed or offset
  clips composite instead of throwing.
- **`CaptionStyle`** (Models) — the 4 burn-in presets (Clean / Bold / Boxed /
  Top). Sizes (`referenceFontSize`, `referenceStrokeWidth`) are defined against
  a **1080px-tall reference frame** and scaled to the real render size at export
  time. Add a new look by appending a preset here; `id`s must stay unique.

## Conventions

- Async AVFoundation/Speech callbacks are bridged with
  `withCheckedThrowingContinuation`, guarded so the continuation resumes once.
- User-facing errors are `LocalizedError` enums per service
  (`TranscriptionError`, `CaptionBurnerError`) with Japanese `errorDescription`;
  the view model surfaces `errorDescription` directly.
- `Info.plist` is generated from `project.yml` (note the
  `NSSpeechRecognitionUsageDescription` key) and is git-ignored — edit
  `project.yml`, not the plist.
