import AppKit
import Observation
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let windowTracker = WindowTracker()
    private let simulatorControl = SimulatorControl()
    private var isPanelVisible = true
    private var lastSimulatorFrame: CGRect?
    private var lastWindowCount = 0
    private var hasSynced = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupPanel()
        setupTracking()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "iphone.gen3",
                accessibilityDescription: "Steroid"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Toggle Panel",
            action: #selector(togglePanel),
            keyEquivalent: "t"
        ))
        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
        menu.delegate = self
    }

    // MARK: - Panel

    private func setupPanel() {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 680)
        )

        let contentView = ControlPanelView(
            control: simulatorControl,
            windowTracker: windowTracker
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = panel.contentView!
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }

    // MARK: - Tracking

    private func setupTracking() {
        // Direct callback: AX observer → panel position, zero async hops
        windowTracker.onFrameChanged = { [weak self] frame in
            guard let self, self.isPanelVisible else { return }
            self.lastSimulatorFrame = frame
            self.positionPanel(relativeTo: frame)
        }
        windowTracker.startTracking()
        observeChanges()
    }

    private func observeChanges() {
        withObservationTracking {
            handleTrackerUpdate(
                frame: windowTracker.simulatorFrame,
                focused: windowTracker.isSimulatorFocused,
                windowCount: windowTracker.simulatorWindowCount,
                windowTitle: windowTracker.activeWindowTitle,
                windowID: windowTracker.simulatorWindowID
            )
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.observeChanges()
            }
        }
    }

    private func handleTrackerUpdate(frame: CGRect?, focused: Bool, windowCount: Int, windowTitle: String?, windowID: UInt32) {
        guard let frame else {
            panel.orderOut(nil)
            lastSimulatorFrame = nil
            lastWindowCount = 0
            hasSynced = false
            return
        }

        if !hasSynced {
            hasSynced = true
            simulatorControl.syncWithSimulator()
        }

        if windowCount != lastWindowCount {
            lastWindowCount = windowCount
            if hasSynced {
                simulatorControl.refreshDevices()
            }
        }

        simulatorControl.simulatorWindowID = windowID

        // Auto-select device based on focused Simulator window
        if let title = windowTitle {
            simulatorControl.selectDeviceByWindowTitle(title)
        }

        if frame != lastSimulatorFrame {
            lastSimulatorFrame = frame
            positionPanel(relativeTo: frame)
        }

        if isPanelVisible {
            if focused {
                panel.level = .floating
                panel.orderFront(nil)
            } else {
                panel.level = .normal
                panel.orderBack(nil)
            }
        }
    }

    private func positionPanel(relativeTo simulatorFrame: CGRect) {
        guard let screen = NSScreen.screens.first else { return }
        let screenHeight = screen.frame.height
        let panelWidth = panel.frame.width
        let panelHeight = simulatorFrame.height

        let panelX = simulatorFrame.maxX + 12
        let panelY = screenHeight - simulatorFrame.origin.y - panelHeight

        var frame = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

        if frame.maxX > screen.visibleFrame.maxX {
            frame.origin.x = simulatorFrame.origin.x - panelWidth - 12
        }

        frame.origin.y = max(
            screen.visibleFrame.minY,
            min(frame.origin.y, screen.visibleFrame.maxY - panelHeight)
        )

        panel.setFrame(frame, display: true)
    }

    @objc private func togglePanel() {
        isPanelVisible.toggle()
        if isPanelVisible, windowTracker.simulatorFrame != nil {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: - Launch at Login

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Failed to toggle launch at login: \(error)")
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.items.first(where: { $0.action == #selector(toggleLaunchAtLogin) }) {
            item.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }
}
