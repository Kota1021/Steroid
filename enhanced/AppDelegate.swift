import AppKit
import Observation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let windowTracker = WindowTracker()
    private let simulatorControl = SimulatorControl()
    private var isPanelVisible = true
    private var lastSimulatorFrame: CGRect?
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
                accessibilityDescription: "Simulator Enhanced"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Toggle Panel",
            action: #selector(togglePanel),
            keyEquivalent: "t"
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    // MARK: - Panel

    private func setupPanel() {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 520)
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
        windowTracker.startTracking()
        observeChanges()
    }

    private func observeChanges() {
        withObservationTracking {
            handleTrackerUpdate(
                frame: windowTracker.simulatorFrame,
                focused: windowTracker.isSimulatorFocused
            )
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.observeChanges()
            }
        }
    }

    private func handleTrackerUpdate(frame: CGRect?, focused: Bool) {
        guard let frame else {
            panel.orderOut(nil)
            lastSimulatorFrame = nil
            hasSynced = false
            return
        }

        if !hasSynced {
            hasSynced = true
            simulatorControl.syncWithSimulator()
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
        let panelSize = panel.frame.size

        // CG coords: top-left origin → NS coords: bottom-left origin
        // Align panel top with simulator top
        let panelX = simulatorFrame.maxX + 12
        let panelY = screenHeight - simulatorFrame.origin.y - panelSize.height

        var origin = NSPoint(x: panelX, y: panelY)

        // Fall back to left side if off-screen right
        if panelX + panelSize.width > screen.visibleFrame.maxX {
            origin.x = simulatorFrame.origin.x - panelSize.width - 12
        }

        // Clamp Y to visible area
        origin.y = max(
            screen.visibleFrame.minY,
            min(origin.y, screen.visibleFrame.maxY - panelSize.height)
        )

        panel.setFrameOrigin(origin)
    }

    @objc private func togglePanel() {
        isPanelVisible.toggle()
        if isPanelVisible, windowTracker.simulatorFrame != nil {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }
}
