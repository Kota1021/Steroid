# Steroid

iOS Simulator 用フローティングコントロールパネル (macOS menu bar app)。

## Architecture

```
SteroidApp.swift        @main, menu bar app (LSUIElement)
  └─ AppDelegate.swift  Status bar menu, panel lifecycle, Launch at Login (SMAppService)
FloatingPanel.swift     Non-activating NSPanel (HUD vibrancy)
WindowTracker.swift     CGWindowList + AXUIElement で Simulator 追跡
SimulatorControl.swift  xcrun simctl wrapper
ControlPanelView.swift  SwiftUI UI
```

## Build

```sh
open Steroid.xcodeproj  # Team 選択 → Run
xcodebuild -scheme Steroid -configuration Debug build
```

## Requirements

- macOS 15+, Xcode 16+
- Accessibility permission 必須
- App Sandbox OFF
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
