import SwiftUI

struct ControlPanelView: View {
    @Bindable var control: SimulatorControl
    var windowTracker: WindowTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with active device
            HStack(spacing: 6) {
                Circle()
                    .fill(windowTracker.isSimulatorRunning ? .green : .secondary)
                    .frame(width: 8, height: 8)
                if let device = control.selectedDevice {
                    Text(device.name)
                        .font(.headline)
                    Text(device.runtime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Simulator")
                        .font(.headline)
                }
                Spacer()
            }

            if windowTracker.isSimulatorRunning {
                connectedContent
            } else {
                disconnectedContent
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 260)
        .environment(\.controlActiveState, .key)
    }

    // MARK: - Connected

    @ViewBuilder
    private var connectedContent: some View {
        Divider()

        // Appearance
        VStack(alignment: .leading, spacing: 8) {
            Label("Appearance", systemImage: "circle.lefthalf.filled")
                .font(.subheadline.weight(.medium))

            Picker("", selection: $control.isDarkMode) {
                Label("Light", systemImage: "sun.max").tag(false)
                Label("Dark", systemImage: "moon").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: control.isDarkMode) { _, _ in
                control.applyAppearance()
            }
        }

        Divider()

        // Dynamic Type
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Dynamic Type", systemImage: "textformat.size")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(control.currentSizeLabel)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            HStack(spacing: 4) {
                Text("A")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Slider(
                    value: $control.contentSizeIndex,
                    in: 0...Double(SimulatorControl.contentSizes.count - 1),
                    step: 1
                )
                .onChange(of: control.contentSizeIndex) { _, _ in
                    control.applyContentSize()
                }
                Text("A")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }

        Divider()

        // Accessibility
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility", systemImage: "accessibility")
                .font(.subheadline.weight(.medium))

            accessibilityToggle("Invert Colors", systemImage: "circle.righthalf.filled",
                                isOn: $control.invertColors) { control.applyInvertColors() }
            accessibilityToggle("Increase Contrast", systemImage: "circle.circle",
                                isOn: $control.increaseContrast) { control.applyIncreaseContrast() }
            accessibilityToggle("Reduce Transparency", systemImage: "square.on.square.dashed",
                                isOn: $control.reduceTransparency) { control.applyReduceTransparency() }
            accessibilityToggle("Reduce Motion", systemImage: "figure.walk.motion",
                                isOn: $control.reduceMotion) { control.applyReduceMotion() }
            accessibilityToggle("On/Off Labels", systemImage: "togglepower",
                                isOn: $control.onOffLabels) { control.applyOnOffLabels() }
            accessibilityToggle("Button Shapes", systemImage: "rectangle.roundedtop",
                                isOn: $control.buttonShapes) { control.applyButtonShapes() }
            accessibilityToggle("Grayscale", systemImage: "paintpalette",
                                isOn: $control.grayscale) { control.applyGrayscale() }
            accessibilityToggle("Without Color", systemImage: "circle.lefthalf.striped.horizontal",
                                isOn: $control.differentiateWithoutColor) { control.applyDifferentiateWithoutColor() }
        }

        Divider()

        // Capture
        HStack(spacing: 12) {
            Button {
                control.takeScreenshot()
            } label: {
                Label("Screenshot", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)

            Button {
                control.toggleRecording()
            } label: {
                Label(control.isRecording ? "Stop" : "Record",
                      systemImage: control.isRecording ? "stop.circle.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .tint(control.isRecording ? .red : nil)
        }
    }

    // MARK: - Helpers

    private func accessibilityToggle(
        _ title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        apply: @escaping () -> Void
    ) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .labelReservedIconWidth(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .onChange(of: isOn.wrappedValue) { _, _ in apply() }
    }

    // MARK: - Disconnected

    private var disconnectedContent: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "iphone.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Simulator Running")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let tracker = WindowTracker()
    tracker.simulatorFrame = CGRect(x: 0, y: 0, width: 400, height: 800)
    return ControlPanelView(
        control: SimulatorControl(),
        windowTracker: tracker
    )
}
