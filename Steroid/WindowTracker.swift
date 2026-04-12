import AppKit
import ApplicationServices
import Observation

@Observable
class WindowTracker {
    var simulatorFrame: CGRect?
    var simulatorWindowID: UInt32 = 0
    var isSimulatorFocused = false
    var simulatorWindowCount = 0
    var activeWindowTitle: String?

    @ObservationIgnored private var positionTimer: Timer?
    @ObservationIgnored private var stateTimer: Timer?
    @ObservationIgnored private var activationObserver: Any?
    @ObservationIgnored private var trackedPID: pid_t = 0
    @ObservationIgnored private var fastTickCount = 0

    /// Direct callback — bypasses @Observable for zero-latency panel repositioning
    @ObservationIgnored var onFrameChanged: ((CGRect) -> Void)?

    var isSimulatorRunning: Bool {
        simulatorFrame != nil
    }

    func startTracking() {
        updateSimulatorState()

        // 60fps: lightweight single-window position tracking
        let fast = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateWindowPosition()
        }
        RunLoop.main.add(fast, forMode: .common)
        positionTimer = fast

        // 2s: full state (window count, title, device detection)
        stateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateSimulatorState()
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let isSimulator = app.bundleIdentifier == "com.apple.iphonesimulator"
            self?.isSimulatorFocused = isSimulator
            if isSimulator {
                self?.updateSimulatorState()
            }
        }
    }

    func stopTracking() {
        positionTimer?.invalidate()
        positionTimer = nil
        stateTimer?.invalidate()
        stateTimer = nil
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activationObserver = nil
        }
    }

    // MARK: - Fast path (60fps) — single window position only

    private func updateWindowPosition() {
        guard simulatorWindowID != 0, trackedPID != 0 else { return }

        // Every ~100ms (6 ticks at 60fps): check if frontmost window changed
        fastTickCount += 1
        if fastTickCount % 6 == 0,
           let frontWID = frontmostSimulatorWindowID(),
           frontWID != simulatorWindowID {
            updateSimulatorState()
            return
        }

        // Query only the tracked window (not the entire window list)
        guard let infos = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow],
            CGWindowID(simulatorWindowID)
        ) as? [[String: Any]],
              let window = infos.first,
              let boundsDict = window[kCGWindowBounds as String],
              let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary)
        else { return }

        onFrameChanged?(rect)
        if simulatorFrame != rect {
            simulatorFrame = rect
        }
    }

    /// Returns the window ID of the frontmost Simulator window, or nil
    private func frontmostSimulatorWindowID() -> UInt32? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == trackedPID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = window[kCGWindowBounds as String],
                  let rect = CGRect(dictionaryRepresentation: boundsDict as! CFDictionary),
                  rect.width > 100, rect.height > 100,
                  let wid = window[kCGWindowNumber as String] as? Int
            else { continue }
            return UInt32(wid)
        }
        return nil
    }

    // MARK: - Slow path (2s) — full state discovery

    private func updateSimulatorState() {
        let simulatorApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.apple.iphonesimulator"
        }

        guard let simulatorApp = simulatorApps.first else {
            if simulatorFrame != nil { simulatorFrame = nil }
            if simulatorWindowCount != 0 { simulatorWindowCount = 0 }
            if activeWindowTitle != nil { activeWindowTitle = nil }
            simulatorWindowID = 0
            trackedPID = 0
            return
        }

        let pid = simulatorApp.processIdentifier
        trackedPID = pid

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return
        }

        var frontmostFrame: CGRect?
        var frontmostWID: UInt32 = 0
        var count = 0

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = window[kCGWindowBounds as String]
            else { continue }

            guard let rect = CGRect(
                dictionaryRepresentation: boundsDict as! CFDictionary
            ) else { continue }

            guard rect.width > 100, rect.height > 100 else { continue }

            count += 1
            if frontmostFrame == nil {
                frontmostFrame = rect
                if let wid = window[kCGWindowNumber as String] as? Int {
                    frontmostWID = UInt32(wid)
                }
            }
        }

        if simulatorWindowID != frontmostWID {
            simulatorWindowID = frontmostWID
        }
        if simulatorFrame != frontmostFrame {
            simulatorFrame = frontmostFrame
        }
        if simulatorWindowCount != count {
            simulatorWindowCount = count
        }

        let title = focusedWindowTitle(pid: pid)
        if activeWindowTitle != title {
            activeWindowTitle = title
        }
    }

    private func focusedWindowTitle(pid: pid_t) -> String? {
        let axApp = AXUIElementCreateApplication(pid)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            axApp, kAXFocusedWindowAttribute as CFString, &focusedRef
        ) == .success else { return nil }

        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedRef as! AXUIElement, kAXTitleAttribute as CFString, &titleRef
        ) == .success else { return nil }

        return titleRef as? String
    }
}
