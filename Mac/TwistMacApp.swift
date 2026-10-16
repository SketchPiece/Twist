import AppKit
import SwiftUI

@main
struct TwistMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = MacModel.shared
    @State private var hub = Hub.shared

    var body: some Scene {
        Window("Twist", id: "home") {
            HomeView()
                .environment(model)
                .environment(hub)
                .frame(width: 420, height: 660)
                .onAppear { NSApp.setActivationPolicy(.regular) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        // Started at login to stay in the menu bar: don't pop the window up then.
        .defaultLaunchBehavior(hub.inRing ? .suppressed : .presented)

        Window("Devices", id: "devices") {
            DevicesView()
                .environment(model)
                .environment(hub)
                .onAppear { NSApp.setActivationPolicy(.regular) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra(isInserted: .constant(hub.inRing)) {
            MenuContent()
                .environment(model)
                .environment(hub)
        } label: {
            Image(nsImage: .menuDial(locked: model.session != nil))
        }
    }
}

/// The menu bar menu: shown once the Mac is in a ring, since it keeps running for it.
private struct MenuContent: View {
    @Environment(MacModel.self) private var model
    @Environment(Hub.self) private var hub
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let s = model.session {
            Text("Locked until \(TimeText.time(s.end))")
        } else {
            Text("Not locked")
        }
        Divider()
        Section("Devices") {
            ForEach(hub.members) { d in
                let on = d.id == hub.me.id || hub.isNearby(d.id)
                Label(d.id == hub.me.id ? "This \(d.name)" : d.name, systemImage: on ? "circle.fill" : "circle")
            }
        }
        Divider()
        Button("Lock…") { show("home") }
            .keyboardShortcut("l")
            .disabled(model.session != nil)
        Button("Devices…") { show("devices") }
        Divider()
        Text("Twist keeps running here so your other devices can lock this Mac.")
    }

    private func show(_ id: String) {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension NSImage {
    /// The dial dot from the wordmark, as a template for the menu bar.
    static func menuDial(locked: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let r = rect.insetBy(dx: 1.5, dy: 1.5)
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let ring = NSBezierPath(ovalIn: r)
            ring.lineWidth = 1.6
            ring.stroke()
            let c = NSPoint(x: r.midX, y: r.midY)
            let wedge = NSBezierPath()
            wedge.move(to: c)
            wedge.appendArc(withCenter: c, radius: r.width / 2, startAngle: 90, endAngle: locked ? -270 : -30, clockwise: true)
            wedge.close()
            wedge.fill()
            return true
        }
        img.isTemplate = true
        return img
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var pairPanel: PairPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            NSApp.registerForRemoteNotifications()
            pairPanel = PairPanel(hub: Hub.shared)
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppDelegate.hideDockIfIdle() }
            }
            #if DEBUG
            // `-twistTestSeconds 20` locks for a few seconds, for trying the lock out.
            let test = UserDefaults.standard.double(forKey: "twistTestSeconds")
            if test > 0 { MacModel.shared.start(seconds: test); return }
            #endif
            MacModel.shared.resume()
            if Hub.shared.inRing { NSApp.setActivationPolicy(.accessory) }
        }
    }

    /// In a ring, closing the last window leaves Twist in the menu bar only.
    @MainActor
    private static func hideDockIfIdle() {
        guard Hub.shared.inRing, MacModel.shared.session == nil else { return }
        DispatchQueue.main.async {
            let visible = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }
            if !visible { NSApp.setActivationPolicy(.accessory) }
        }
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task { @MainActor in await Hub.shared.pull() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            MacModel.shared.session == nil ? .terminateNow : .terminateCancel
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated { !Hub.shared.inRing }
    }
}
