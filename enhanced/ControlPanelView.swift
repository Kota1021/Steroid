import SwiftUI

struct ControlPanelView: View {
    @Bindable var control: SimulatorControl
    var windowTracker: WindowTracker

    // Section expansion state
    @State private var showAppearance = true
    @State private var showDynamicType = true
    @State private var showAccessibility = true
    @State private var showCapture = true
    @State private var showStatusBar = false
    @State private var showLocation = false
    @State private var showPush = false
    @State private var showPrivacy = false
    @State private var showOpenURL = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if windowTracker.isSimulatorRunning {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        connectedContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            } else {
                disconnectedContent
                    .padding(16)
            }
        }
        .frame(width: 260)
        .environment(\.controlActiveState, .key)
    }

    // MARK: - Connected

    @ViewBuilder
    private var connectedContent: some View {
        section("Appearance", systemImage: "circle.lefthalf.filled", isExpanded: $showAppearance) {
            Picker("", selection: $control.isDarkMode) {
                Label("Light", systemImage: "sun.max").tag(false)
                Label("Dark", systemImage: "moon").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: control.isDarkMode) { _, _ in control.applyAppearance() }
        }

        section("Dynamic Type", systemImage: "textformat.size", isExpanded: $showDynamicType) {
            HStack {
                Spacer()
                Text(control.currentSizeLabel)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            HStack(spacing: 4) {
                Text("A").font(.system(size: 9)).foregroundStyle(.secondary)
                Slider(
                    value: $control.contentSizeIndex,
                    in: 0...Double(SimulatorControl.contentSizes.count - 1),
                    step: 1
                )
                .onChange(of: control.contentSizeIndex) { _, _ in control.applyContentSize() }
                Text("A").font(.system(size: 16)).foregroundStyle(.secondary)
            }
        }

        section("Accessibility", systemImage: "accessibility", isExpanded: $showAccessibility) {
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

        section("Capture", systemImage: "camera", isExpanded: $showCapture) {
            Toggle(isOn: $control.showTouches) {
                Label("Show Touches", systemImage: "hand.tap")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: control.showTouches) { _, _ in control.applyShowTouches() }

            HStack(spacing: 8) {
                Button { control.takeScreenshot() } label: {
                    Label("Screenshot", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)

                Button { control.toggleRecording() } label: {
                    Label(control.isRecording ? "Stop" : "Record",
                          systemImage: control.isRecording ? "stop.circle.fill" : "record.circle")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .tint(control.isRecording ? .red : nil)
            }
        }

        section("Status Bar", systemImage: "wifi", isExpanded: $showStatusBar) {
            statusBarContent
        }

        section("Location", systemImage: "location", isExpanded: $showLocation) {
            locationContent
        }

        section("Push Notification", systemImage: "bell", isExpanded: $showPush) {
            pushContent
        }

        section("Privacy", systemImage: "lock.shield", isExpanded: $showPrivacy) {
            privacyContent
        }

        section("Open URL", systemImage: "link", isExpanded: $showOpenURL) {
            openURLContent
        }
    }

    // MARK: - Status Bar

    private var statusBarContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Time")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("9:41", text: $control.statusBarTime)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
            HStack {
                Text("Network")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $control.statusBarNetwork) {
                    ForEach(SimulatorControl.dataNetworkTypes, id: \.self) { Text($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }
            HStack {
                Text("WiFi")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $control.statusBarWiFiBars) {
                    ForEach(0...3, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
            HStack {
                Text("Cell")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $control.statusBarCellularBars) {
                    ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
            HStack {
                Text("Carrier")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Carrier", text: $control.statusBarOperator)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
            HStack {
                Text("Battery")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $control.statusBarBatteryState) {
                    ForEach(SimulatorControl.batteryStates, id: \.self) { Text($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                Text("\(Int(control.statusBarBatteryLevel))%")
                    .font(.caption.monospaced())
                    .frame(width: 32)
            }
            Slider(value: $control.statusBarBatteryLevel, in: 0...100, step: 1)
                .controlSize(.small)
            HStack(spacing: 8) {
                Button("Apply") { control.applyStatusBar() }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                Button("Clear") { control.clearStatusBar() }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Location

    private var locationContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                TextField("Lat", text: $control.locationLat)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                TextField("Lon", text: $control.locationLon)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                Button("Set") { control.setLocation() }
                    .controlSize(.small)
                    .disabled(control.locationLat.isEmpty || control.locationLon.isEmpty)
            }
            HStack(spacing: 4) {
                Picker("", selection: $control.locationScenario) {
                    ForEach(SimulatorControl.locationScenarios, id: \.self) { Text($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                Button("Run") { control.runLocationScenario() }
                    .controlSize(.small)
            }
            if control.isLocationRunning {
                Button("Clear Location") { control.clearLocation() }
                    .controlSize(.small)
                    .tint(.red)
            }
        }
    }

    // MARK: - Push

    private var pushContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Bundle ID", text: $control.pushBundleID)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            TextField("Title", text: $control.pushTitle)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            TextField("Body", text: $control.pushBody)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            Button("Send Push") { control.sendPush() }
                .controlSize(.small)
                .disabled(control.pushBundleID.isEmpty)
        }
    }

    // MARK: - Privacy

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Service", selection: $control.privacyService) {
                ForEach(SimulatorControl.privacyServices, id: \.value) {
                    Text($0.label).tag($0.value)
                }
            }
            .pickerStyle(.menu)
            .controlSize(.small)

            TextField("Bundle ID", text: $control.privacyBundleID)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            HStack(spacing: 6) {
                Button("Grant") { control.grantPrivacy() }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .disabled(control.privacyBundleID.isEmpty)
                Button("Revoke") { control.revokePrivacy() }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .disabled(control.privacyBundleID.isEmpty)
                Button("Reset") { control.resetPrivacy() }
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Open URL

    private var openURLContent: some View {
        HStack(spacing: 4) {
            TextField("https://", text: $control.openURLString)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            Button("Open") { control.openURL() }
                .controlSize(.small)
                .disabled(control.openURLString.isEmpty)
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            DisclosureGroup(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.top, 4)
            } label: {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.vertical, 6)
        }
    }

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
