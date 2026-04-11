import Foundation
import Observation

struct BootedDevice: Identifiable, Sendable {
    let udid: String
    let name: String
    let runtime: String
    var id: String { udid }
}

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

    // Device management
    var bootedDevices: [BootedDevice] = []
    var selectedDeviceUDID = ""

    var selectedDevice: BootedDevice? {
        bootedDevices.first { $0.udid == selectedDeviceUDID }
    }

    private var deviceId: String {
        selectedDeviceUDID.isEmpty ? "booted" : selectedDeviceUDID
    }

    func selectDeviceByWindowTitle(_ title: String) {
        // Sort longest name first to avoid "iPhone 16" matching before "iPhone 16 Pro"
        let sorted = bootedDevices.sorted { $0.name.count > $1.name.count }
        guard let device = sorted.first(where: { title.hasPrefix($0.name) }) else { return }
        if selectedDeviceUDID != device.udid {
            selectedDeviceUDID = device.udid
            syncSettings()
        }
    }

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
        simctl(["ui", deviceId, "appearance", isDarkMode ? "dark" : "light"])
    }

    func applyContentSize() {
        let idx = min(max(Int(contentSizeIndex), 0), Self.contentSizes.count - 1)
        simctl(["ui", deviceId, "content_size", Self.contentSizes[idx].value])
    }

    func applyInvertColors() {
        setAccessibilityPref("InvertColorsEnabled", enabled: invertColors)
    }

    func applyIncreaseContrast() {
        simctl(["ui", deviceId, "increase_contrast", increaseContrast ? "enabled" : "disabled"])
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

    // MARK: - Capture

    var showTouches = false
    var isRecording = false
    var simulatorWindowID: UInt32 = 0
    @ObservationIgnored private var recordingProcess: Process?

    func applyShowTouches() {
        simctl(["spawn", deviceId, "defaults", "write",
                "com.apple.preferences.touch", "ShowSingleTouches",
                "-bool", showTouches ? "YES" : "NO"])
    }

    private func captureFileName(ext: String) -> String {
        let device = selectedDevice
        let name = device?.name ?? "Simulator"
        let runtime = device?.runtime.replacingOccurrences(of: " ", with: "") ?? ""
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = df.string(from: Date())
        return "\(name)-\(runtime)-\(timestamp).\(ext)"
    }

    func takeScreenshot() {
        let id = deviceId
        let filename = captureFileName(ext: "png")
        Task.detached {
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let path = desktop.appendingPathComponent(filename).path
            Self.runSimctlSync(["io", id, "screenshot", "--mask=black", path])
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let id = deviceId
        let windowID = simulatorWindowID
        isRecording = true

        if showTouches, windowID != 0 {
            // Window capture via screencapture — includes touch overlay
            let filename = captureFileName(ext: "mov")
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let path = desktop.appendingPathComponent(filename).path
            Task.detached { @MainActor [weak self] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                process.arguments = ["-v", "-o", "-l", String(windowID), path]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
                self?.recordingProcess = process
            }
        } else {
            // Device framebuffer capture via simctl
            let filename = captureFileName(ext: "mp4")
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let path = desktop.appendingPathComponent(filename).path
            Task.detached { @MainActor [weak self] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                process.arguments = ["simctl", "io", id, "recordVideo", "--codec=h264", "--force", path]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
                self?.recordingProcess = process
            }
        }
    }

    private func stopRecording() {
        recordingProcess?.interrupt() // sends SIGINT to stop recording
        recordingProcess = nil
        isRecording = false
    }

    // MARK: - Sync

    func syncWithSimulator() {
        Task {
            let devices = await Task.detached { Self.fetchBootedDevices() }.value
            bootedDevices = devices
            if !devices.contains(where: { $0.udid == selectedDeviceUDID }) {
                selectedDeviceUDID = devices.first?.udid ?? ""
            }
            await applyFetchedState()
        }
    }

    func syncSettings() {
        Task { await applyFetchedState() }
    }

    func refreshDevices() {
        Task {
            let devices = await Task.detached { Self.fetchBootedDevices() }.value
            bootedDevices = devices
            if !devices.contains(where: { $0.udid == selectedDeviceUDID }) {
                selectedDeviceUDID = devices.first?.udid ?? ""
            }
        }
    }

    private func applyFetchedState() async {
        let id = deviceId
        let state = await Task.detached { Self.fetchCurrentState(deviceId: id) }.value
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
        showTouches = state.showTouches
    }

    // MARK: - Fetch (nonisolated)

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
        let showTouches: Bool
    }

    nonisolated private static func fetchCurrentState(deviceId: String) -> State {
        // Launch all 5 processes concurrently
        let (appProc, appPipe) = startSimctl(["ui", deviceId, "appearance"])
        let (csProc, csPipe) = startSimctl(["ui", deviceId, "content_size"])
        let (conProc, conPipe) = startSimctl(["ui", deviceId, "increase_contrast"])
        let (accProc, accPipe) = startSimctl([
            "spawn", deviceId, "defaults", "read", "com.apple.Accessibility",
        ])
        let (touchProc, touchPipe) = startSimctl([
            "spawn", deviceId, "defaults", "read",
            "com.apple.preferences.touch", "ShowSingleTouches",
        ])

        // Wait for all to finish
        appProc.waitUntilExit()
        csProc.waitUntilExit()
        conProc.waitUntilExit()
        accProc.waitUntilExit()
        touchProc.waitUntilExit()

        let appearance = readPipe(appPipe)
        let contentSize = readPipe(csPipe)
        let contrast = readPipe(conPipe)
        let acc = parseAccessibilityDefaults(readPipe(accPipe))
        let touchValue = readPipe(touchPipe)

        let contentSizeIdx: Double
        if let idx = contentSizes.firstIndex(where: { $0.value == contentSize }) {
            contentSizeIdx = Double(idx)
        } else {
            contentSizeIdx = 3
        }

        return State(
            isDarkMode: appearance == "dark",
            contentSizeIndex: contentSizeIdx,
            invertColors: acc["InvertColorsEnabled"] ?? false,
            increaseContrast: contrast == "enabled",
            reduceTransparency: acc["EnhancedBackgroundContrastEnabled"] ?? false,
            reduceMotion: acc["ReduceMotionEnabled"] ?? false,
            onOffLabels: acc["OnOffLabelsEnabled"] ?? false,
            buttonShapes: acc["ButtonShapesEnabled"] ?? false,
            grayscale: acc["GrayscaleEnabled"] ?? false,
            differentiateWithoutColor: acc["DifferentiateWithoutColor"] ?? false,
            showTouches: touchValue == "1"
        )
    }

    private struct DeviceList: Decodable, Sendable {
        let devices: [String: [DeviceEntry]]
    }

    private struct DeviceEntry: Decodable, Sendable {
        let udid: String
        let name: String
        let state: String
    }

    nonisolated private static func fetchBootedDevices() -> [BootedDevice] {
        let json = readSimctl(["list", "devices", "booted", "-j"])
        guard let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode(DeviceList.self, from: data)
        else { return [] }

        return list.devices.flatMap { runtime, entries in
            entries.filter { $0.state == "Booted" }.map { entry in
                BootedDevice(
                    udid: entry.udid,
                    name: entry.name,
                    runtime: formatRuntime(runtime)
                )
            }
        }
    }

    nonisolated private static func formatRuntime(_ identifier: String) -> String {
        // "com.apple.CoreSimulator.SimRuntime.iOS-26-2" → "iOS 26.2"
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        let cleaned = identifier.hasPrefix(prefix)
            ? String(identifier.dropFirst(prefix.count))
            : identifier
        let parts = cleaned.split(separator: "-")
        guard parts.count >= 2 else { return cleaned }
        return "\(parts[0]) \(parts[1...].joined(separator: "."))"
    }

    nonisolated private static func runSimctlSync(_ arguments: [String]) {
        let (process, _) = startSimctl(arguments)
        process.waitUntilExit()
    }

    nonisolated private static func startSimctl(_ arguments: [String]) -> (Process, Pipe) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl"] + arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        return (process, pipe)
    }

    nonisolated private static func readPipe(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    nonisolated private static func readSimctl(_ arguments: [String]) -> String {
        let (process, pipe) = startSimctl(arguments)
        process.waitUntilExit()
        return readPipe(pipe)
    }

    nonisolated private static func parseAccessibilityDefaults(_ output: String) -> [String: Bool] {
        var dict: [String: Bool] = [:]
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eqRange = trimmed.range(of: " = ") else { continue }
            let key = trimmed[..<eqRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let rawValue = String(trimmed[eqRange.upperBound...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "; \t\""))
            dict[key] = rawValue == "1"
        }
        return dict
    }

    // MARK: - Private

    private func setAccessibilityPref(_ key: String, enabled: Bool) {
        simctl([
            "spawn", deviceId, "defaults", "write",
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
