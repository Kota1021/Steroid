import AppKit
import Combine

class WindowTracker: ObservableObject {
    @Published var simulatorFrame: CGRect?

    private var timer: Timer?

    var isSimulatorRunning: Bool {
        simulatorFrame != nil
    }

    func startTracking() {
        updateSimulatorFrame()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateSimulatorFrame()
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }

    private func updateSimulatorFrame() {
        // Find Simulator by bundle ID — no Screen Recording permission needed
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

        // Find the largest Simulator window (the device window)
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
