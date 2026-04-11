import Foundation
import Observation

@Observable
class SimulatorControl {
    var isDarkMode = false
    var contentSizeIndex: Double = 3 // "large" = default

    // Accessibility options (matches Accessibility Inspector order)
    var invertColors = false
    var increaseContrast = false
    var reduceTransparency = false
    var reduceMotion = false
    var onOffLabels = false
    var buttonShapes = false
    var grayscale = false
    var differentiateWithoutColor = false

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

    // MARK: - Sync

    private struct State: Sendable {
        let isDarkMode: Bool
        let contentSizeIndex: Double
        let invertColors: Bool
        let increaseContrast: Bool
        let reduceTransparency: Bool
        let reduceMotion: Bool
        let onOffLabels: Bool
        let buttonShapes: Bool
        let grayscale: Bool
        let differentiateWithoutColor: Bool
    }

    func syncWithSimulator() {
        Task {
            let state = await Task.detached { Self.fetchCurrentState() }.value
            isDarkMode = state.isDarkMode
            contentSizeIndex = state.contentSizeIndex
            invertColors = state.invertColors
            increaseContrast = state.increaseContrast
            reduceTransparency = state.reduceTransparency
            reduceMotion = state.reduceMotion
            onOffLabels = state.onOffLabels
            buttonShapes = state.buttonShapes
            grayscale = state.grayscale
            differentiateWithoutColor = state.differentiateWithoutColor
        }
    }

    nonisolated private static func fetchCurrentState() -> State {
        let appearance = readSimctl(["ui", "booted", "appearance"])
        let contentSize = readSimctl(["ui", "booted", "content_size"])
        let contrast = readSimctl(["ui", "booted", "increase_contrast"])

        let contentSizeIdx: Double
        if let idx = contentSizes.firstIndex(where: { $0.value == contentSize }) {
            contentSizeIdx = Double(idx)
        } else {
            contentSizeIdx = 3 // default "large"
        }

        return State(
            isDarkMode: appearance == "dark",
            contentSizeIndex: contentSizeIdx,
            invertColors: readAccessibilityBool("InvertColorsEnabled"),
            increaseContrast: contrast == "enabled",
            reduceTransparency: readAccessibilityBool("EnhancedBackgroundContrastEnabled"),
            reduceMotion: readAccessibilityBool("ReduceMotionEnabled"),
            onOffLabels: readAccessibilityBool("OnOffLabelsEnabled"),
            buttonShapes: readAccessibilityBool("ButtonShapesEnabled"),
            grayscale: readAccessibilityBool("GrayscaleEnabled"),
            differentiateWithoutColor: readAccessibilityBool("DifferentiateWithoutColor")
        )
    }

    nonisolated private static func readSimctl(_ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    nonisolated private static func readAccessibilityBool(_ key: String) -> Bool {
        readSimctl(["spawn", "booted", "defaults", "read", "com.apple.Accessibility", key]) == "1"
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
