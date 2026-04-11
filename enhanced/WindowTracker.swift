import AppKit
import Observation

@Observable
class WindowTracker {
    var simulatorFrame: CGRect?
    var isSimulatorFocused = false

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
            return
        }

        let pid = simulatorApp.processIdentifier

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return
        }

        var bestFrame: CGRect?
        var bestArea: CGFloat = 0

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

            let area = rect.width * rect.height
            if area > bestArea {
                bestArea = area
                bestFrame = rect
            }
        }

        if simulatorFrame != bestFrame {
            simulatorFrame = bestFrame
        }
    }
}
