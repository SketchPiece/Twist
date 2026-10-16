import AppKit
import ServiceManagement
import SwiftUI

/// Covers every screen with the lock and keeps the rest of the Mac out of reach:
/// kiosk presentation options (no Dock, menu bar, ⌘Tab, Force Quit, log out),
/// windows above everything on all Spaces, focus taken back if anything else
/// gets it, and a login item so a restart lands back on the lock.
@MainActor
final class Lockdown {
    private unowned let model: MacModel
    private var windows: [NSWindow] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?
    private var engaged = false

    private static let options: NSApplication.PresentationOptions = [
        .hideDock, .hideMenuBar,
        .disableProcessSwitching, .disableForceQuit, .disableSessionTermination,
        .disableHideApplication, .disableAppleMenu, .disableMenuBarTransparency,
    ]

    init(model: MacModel) {
        self.model = model
    }

    func engage() {
        guard !engaged else { return }
        engaged = true

        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = Self.options
        buildWindows()

        let app = NotificationCenter.default
        let ws = NSWorkspace.shared.notificationCenter
        observe(app, NSApplication.didChangeScreenParametersNotification) { $0.buildWindows() }
        observe(app, NSApplication.didResignActiveNotification) { $0.grab() }
        observe(ws, NSWorkspace.didActivateApplicationNotification) { $0.grab() }
        observe(ws, NSWorkspace.activeSpaceDidChangeNotification) { $0.grab() }
        observe(ws, NSWorkspace.didWakeNotification) { $0.model.tick(); $0.grab() }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.tick()
                if self.engaged, !NSApp.isActive { self.grab() }
            }
        }

        try? SMAppService.mainApp.register()
    }

    func release() {
        guard engaged else { return }
        engaged = false
        timer?.invalidate()
        timer = nil
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
        for w in windows { w.orderOut(nil) }
        windows = []
        NSApp.presentationOptions = []
    }

    /// Bring the lock back to the front and take keyboard focus.
    private func grab() {
        guard engaged else { return }
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.presentationOptions != Self.options { NSApp.presentationOptions = Self.options }
        for w in windows { w.orderFrontRegardless() }
        windows.first?.makeKey()
    }

    private func buildWindows() {
        for w in windows { w.orderOut(nil) }
        // screens[0] is the one with the menu bar; it gets the unwind control and the keyboard.
        windows = NSScreen.screens.enumerated().map { i, screen in
            let primary = i == 0
            let w = ShieldWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            w.isReleasedWhenClosed = false
            w.backgroundColor = NSColor(Color.night)
            w.hasShadow = false
            w.animationBehavior = .none
            w.contentView = NSHostingView(rootView: LockRoot(primary: primary).environment(model))
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            return w
        }
        windows.first?.makeKey()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ run: @escaping (Lockdown) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.engaged else { return }
                run(self)
            }
        }
        observers.append((center, token))
    }
}

/// Borderless windows can't take the keyboard unless they say so.
private final class ShieldWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
