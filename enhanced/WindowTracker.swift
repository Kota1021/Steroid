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

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var activationObserver: Any?

    var isSimulatorRunning: Bool {
        simulatorFrame != nil
    }

    func startTracking() {
        updateSimulatorFrame()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateSimulatorFrame()
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.isSimulatorFocused = app.bundleIdentifier == "com.apple.iphonesimulator"
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        if let observer = activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activationObserver = nil
        }
    }

    private func updateSimulatorFrame() {
        let simulatorApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == "com.apple.iphonesimulator"
        }

        guard let simulatorApp = simulatorApps.first else {
            if simulatorFrame != nil { simulatorFrame = nil }
            if simulatorWindowCount != 0 { simulatorWindowCount = 0 }
            if activeWindowTitle != nil { activeWindowTitle = nil }
            return
        }

        let pid = simulatorApp.processIdentifier

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return
        }

        var frontmostFrame: CGRect?
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
                    let newID = UInt32(wid)
                    if simulatorWindowID != newID { simulatorWindowID = newID }
                }
            }
        }

        if simulatorFrame != frontmostFrame {
            simulatorFrame = frontmostFrame
        }
        if simulatorWindowCount != count {
            simulatorWindowCount = count
        }

        // Get focused Simulator window title via Accessibility API
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
