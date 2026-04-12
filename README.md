# Steroid

A floating control panel for iOS Simulator. Attaches to the Simulator window and provides quick access to settings that normally require digging through menus or CLI commands.

iOS Simulator用のフローティングコントロールパネル。Simulatorウィンドウに追従し、通常メニューやCLIが必要な設定にすばやくアクセスできます。

iOS Simulator的浮动控制面板。自动吸附在Simulator窗口旁边，快速访问通常需要通过菜单或CLI才能更改的设置。
<img width="400" alt="image" src="https://github.com/user-attachments/assets/2d581dc7-2265-47c1-ba3d-8c294b48038b" />

|appearnce|push notification|
|-|-|
|<video width="400" alt="video" src="https://github.com/user-attachments/assets/d3a91b60-1ec0-4efd-a1b1-4c0c83e9cb40" />|<video width="400" alt="video" src="https://github.com/user-attachments/assets/f56f2677-12b2-407d-9b96-19ef44ec3d01" />|







## Features

- **Appearance** — Light/Dark mode toggle
- **Dynamic Type** — Content size slider (XS to Accessibility XXXL)
- **Accessibility** — Invert Colors, Increase Contrast, Reduce Transparency, Reduce Motion, On/Off Labels, Button Shapes, Grayscale, Differentiate Without Color
- **Capture** — Screenshot, screen recording, show touches
- **Status Bar** — Override time, network type, carrier, battery state/level
- **Location** — Set coordinates or run movement scenarios (City Run, Freeway Drive, etc.)
- **Push Notifications** — Send test notifications to any installed app
- **Privacy** — Grant/revoke/reset permissions (photos, location, contacts, etc.)
- **Open URL** — Open URLs in the Simulator

The panel auto-positions next to the Simulator window, follows it when moved, and auto-selects the focused device when multiple simulators are running.

パネルはSimulatorウィンドウの横に自動配置され、ウィンドウの移動に追従します。複数のSimulatorが起動している場合、フォーカス中のデバイスを自動選択します。

面板会自动定位在Simulator窗口旁边，跟随窗口移动。多个Simulator同时运行时，自动选择当前聚焦的设备。

## Requirements

- macOS 15+
- Xcode 16+
- Accessibility permission (System Settings > Privacy & Security > Accessibility)

## Build

Open `Steroid.xcodeproj`, select your team in Signing & Capabilities, and run.

`Steroid.xcodeproj`を開き、Signing & Capabilitiesで自分のTeamを選択して実行。

打开`Steroid.xcodeproj`，在Signing & Capabilities中选择你的Team，然后运行。

## License

MIT
