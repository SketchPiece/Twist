import AppKit
import SwiftUI

@main
struct TwistMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = MacModel.shared

    var body: some Scene {
        Window("Twist", id: "home") {
            HomeView()
                .environment(model)
                .frame(width: 420, height: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            #if DEBUG
            // `-twistTestSeconds 20` locks for a few seconds, for trying the lock out.
            let test = UserDefaults.standard.double(forKey: "twistTestSeconds")
            if test > 0 { MacModel.shared.start(seconds: test); return }
            #endif
            MacModel.shared.resume()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            MacModel.shared.session == nil ? .terminateNow : .terminateCancel
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
