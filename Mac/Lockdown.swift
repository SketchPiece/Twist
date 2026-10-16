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
    private var keys: Any?
    private var engaged = false
    /// The Mac's own lock screen is up: stand back so its password field can take the keyboard.
    private var screenLocked = false

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
        let screen = DistributedNotificationCenter.default()
        observe(screen, .init("com.apple.screenIsLocked")) { $0.screenLocked = true; $0.stepBack() }
        observe(screen, .init("com.apple.screenIsUnlocked")) { $0.screenLocked = false; $0.grab() }

        // Kiosk mode turns off the system's ⌃⌘Q; locking the screen on top of Twist is still allowed.
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mods == [.control, .command], event.charactersIgnoringModifiers?.lowercased() == "q" else { return event }
            Self.lockScreen()
            return nil
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.tick()
                if self.engaged, !self.screenLocked, !NSApp.isActive { self.grab() }
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
        if let keys { NSEvent.removeMonitor(keys) }
        keys = nil
        screenLocked = false
        NSApp.presentationOptions = []

        // Fade the lock away. Each window shows a still of its last frame while it
        // fades, so the screens don't change under it as the model resets.
        let fading = windows
        windows = []
        for w in fading { freeze(w); w.ignoresMouseEvents = true }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            for w in fading { w.animator().alphaValue = 0 }
        } completionHandler: {
            for w in fading { w.orderOut(nil) }
        }
    }

    private func freeze(_ w: NSWindow) {
        guard let view = w.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        let still = NSImageView(frame: view.bounds)
        still.image = image
        still.imageScaling = .scaleAxesIndependently
        w.contentView = still
    }

    /// Bring the lock back to the front and take keyboard focus.
    private func grab() {
        guard engaged, !screenLocked else { return }
        for w in windows { w.level = Self.level }
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.presentationOptions != Self.options { NSApp.presentationOptions = Self.options }
        for w in windows { w.orderFrontRegardless() }
        windows.first?.makeKey()
    }

    private static let level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

    /// Under the Mac's lock screen while it is up.
    private func stepBack() {
        for w in windows { w.level = .normal }
    }

    /// The same as the system's ⌃⌘Q.
    private static func lockScreen() {
        guard let login = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
              let sym = dlsym(login, "SACLockScreenImmediate") else { return }
        typealias Lock = @convention(c) () -> Int32
        _ = unsafeBitCast(sym, to: Lock.self)()
    }

    private func buildWindows() {
        for w in windows { w.orderOut(nil) }
        // screens[0] is the one with the menu bar; it gets the unwind control and the keyboard.
        windows = NSScreen.screens.enumerated().map { i, screen in
            let primary = i == 0
            let w = ShieldWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = screenLocked ? .normal : Self.level
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
    // Keys nothing on the lock uses end up here; swallow them instead of beeping.
    override func keyDown(with event: NSEvent) {}
}
