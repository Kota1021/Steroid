import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let windowTracker = WindowTracker()
    private let simulatorControl = SimulatorControl()
    private var cancellables = Set<AnyCancellable>()
    private var isPanelVisible = true
    private var lastSimulatorFrame: CGRect?

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

        windowTracker.$simulatorFrame
            .receive(on: RunLoop.main)
            .sink { [weak self] frame in
                guard let self else { return }
                guard let frame else {
                    self.panel.orderOut(nil)
                    self.lastSimulatorFrame = nil
                    return
                }

                if frame != self.lastSimulatorFrame {
                    self.lastSimulatorFrame = frame
                    self.positionPanel(relativeTo: frame)
                }

                if self.isPanelVisible {
                    self.panel.orderFront(nil)
                }
            }
            .store(in: &cancellables)

        windowTracker.$isSimulatorFocused
            .receive(on: RunLoop.main)
            .sink { [weak self] focused in
                guard let self, self.isPanelVisible else { return }
                self.panel.level = focused ? .floating : .normal
            }
            .store(in: &cancellables)
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
