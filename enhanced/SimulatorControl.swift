import Combine
import Foundation

class SimulatorControl: ObservableObject {
    @Published var isDarkMode = false
    @Published var contentSizeIndex: Double = 3 // "large" = default

    // Accessibility options (matches Accessibility Inspector order)
    @Published var invertColors = false
    @Published var increaseContrast = false
    @Published var reduceTransparency = false
    @Published var reduceMotion = false
    @Published var onOffLabels = false
    @Published var buttonShapes = false
    @Published var grayscale = false
    @Published var differentiateWithoutColor = false

    static let contentSizes: [(label: String, value: String)] = [
        ("XS",     "extra-small"),
        ("S",      "small"),
        ("M",      "medium"),
        ("L",      "large"),
        ("XL",     "extra-large"),
        ("XXL",    "extra-extra-large"),
        ("XXXL",   "extra-extra-extra-large"),
        ("AX M",   "accessibility-medium"),
        ("AX L",   "accessibility-large"),
        ("AX XL",  "accessibility-extra-large"),
        ("AX XXL", "accessibility-extra-extra-large"),
        ("AX XXXL","accessibility-extra-extra-extra-large"),
    ]

    var currentSizeLabel: String {
        let idx = Int(contentSizeIndex)
        guard idx >= 0, idx < Self.contentSizes.count else { return "?" }
        return Self.contentSizes[idx].label
    }

    // MARK: - Apply

    func applyAppearance() {
        simctl(["ui", "booted", "appearance", isDarkMode ? "dark" : "light"])
    }

    func applyContentSize() {
        let idx = min(max(Int(contentSizeIndex), 0), Self.contentSizes.count - 1)
        simctl(["ui", "booted", "content_size", Self.contentSizes[idx].value])
    }

    func applyInvertColors() {
        setAccessibilityPref("InvertColorsEnabled", enabled: invertColors)
    }

    func applyIncreaseContrast() {
        simctl(["ui", "booted", "increase_contrast", increaseContrast ? "enabled" : "disabled"])
    }

    func applyReduceTransparency() {
        setAccessibilityPref("EnhancedBackgroundContrastEnabled", enabled: reduceTransparency)
    }

    func applyReduceMotion() {
        setAccessibilityPref("ReduceMotionEnabled", enabled: reduceMotion)
    }

    func applyOnOffLabels() {
        setAccessibilityPref("OnOffLabelsEnabled", enabled: onOffLabels)
    }

    func applyButtonShapes() {
        setAccessibilityPref("ButtonShapesEnabled", enabled: buttonShapes)
    }

    func applyGrayscale() {
        setAccessibilityPref("GrayscaleEnabled", enabled: grayscale)
    }

    func applyDifferentiateWithoutColor() {
        setAccessibilityPref("DifferentiateWithoutColor", enabled: differentiateWithoutColor)
    }

    // MARK: - Private

    private func setAccessibilityPref(_ key: String, enabled: Bool) {
        simctl([
            "spawn", "booted", "defaults", "write",
            "com.apple.Accessibility", key, "-bool", enabled ? "YES" : "NO",
        ])
    }

    nonisolated private func simctl(_ arguments: [String]) {
        let args = arguments
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl"] + args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
}
