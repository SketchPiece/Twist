import AppKit
import SwiftUI

/// The Devices window: who locks together with this Mac.
struct DevicesView: View {
    @Environment(Hub.self) private var hub
    @Environment(MacModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Devices")
                .font(.tight(24, .bold))
                .tracking(-0.5)
            Text("Lock one and they all lock. Unwind one and they all open.")
                .font(.tight(15))
                .opacity(0.55)
                .padding(.top, 6)

            VStack(spacing: 0) {
                ForEach(Array(hub.members.enumerated()), id: \.element.id) { i, d in
                    if i > 0 { Divider().opacity(0.6) }
                    DeviceRow(device: d) {
                        if d.id != hub.me.id && model.session == nil {
                            Button("Remove") { hub.remove(d) }
                                .buttonStyle(.plain)
                                .font(.tight(15, .semibold))
                                .opacity(0.5)
                        }
                    }
                }
            }
            .background(Color.paperFace, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.top, 22)

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "iphone").font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add an iPhone or iPad").font(.tight(15, .semibold))
                    Text("Open Twist on it and tap Add a device. This Mac shows up there by itself.")
                        .font(.tight(15))
                        .opacity(0.55)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.graphite.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.top, 10)
        .padding(.bottom, 30)
        .frame(width: 560, height: 520, alignment: .top)
        .foregroundStyle(Color.graphite)
        .background(Color.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        // Bonjour runs while this window is open even before the first pairing.
        .onAppear { hub.start() }
    }
}

/// "iPhone wants to lock together with this Mac", with the code to compare.
struct PairRequestView: View {
    @Environment(Hub.self) private var hub
    var request: Hub.Request

    var body: some View {
        VStack(spacing: 0) {
            PairGlyphs(left: hub.me, right: request.device)
            Text("\(request.device.name) wants to lock together with this Mac")
                .font(.tight(22, .bold))
                .tracking(-0.2)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
            PairCode(code: request.code, size: 52)
                .padding(.top, 22)
            Text("Join only if your \(request.device.name) shows the same code. After that, a lock on either one locks both, and unwinding on either opens both.")
                .font(.tight(15))
                .opacity(0.55)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 380)
                .padding(.top, 8)
            HStack(spacing: 10) {
                Button { hub.decline() } label: { macButton("Not now", primary: false) }
                    .keyboardShortcut(.cancelAction)
                Button { hub.accept() } label: { macButton(request.joining ? "Joining…" : "Join", primary: true) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(request.joining)
            }
            .buttonStyle(.plain)
            .padding(.top, 26)
        }
        .padding(.horizontal, 36)
        .padding(.top, 34)
        .padding(.bottom, 28)
        .frame(width: 480)
        .foregroundStyle(Color.graphite)
        .background(Color.paper)
        .preferredColorScheme(.light)
    }

    private func macButton(_ title: String, primary: Bool) -> some View {
        Text(title)
            .font(.tight(16, .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(primary ? Color.graphite : Color.graphite.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(primary ? Color.paper : Color.graphite)
            .contentShape(Rectangle())
    }
}

/// Shows the pairing request in its own floating panel whenever one comes in,
/// whether or not a Twist window is open.
@MainActor
final class PairPanel {
    private var panel: NSPanel?
    private let hub: Hub

    init(hub: Hub) {
        self.hub = hub
        track()
    }

    private func track() {
        withObservationTracking {
            _ = hub.request
        } onChange: {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.update()
                    self.track()
                }
            }
        }
    }

    private func update() {
        guard let request = hub.request else {
            panel?.orderOut(nil)
            panel = nil
            return
        }
        let view = PairRequestView(request: request).environment(hub)
        if let panel {
            (panel.contentView as? NSHostingView<AnyView>)?.rootView = AnyView(view)
            return
        }
        let p = NSPanel(contentRect: .zero, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.backgroundColor = NSColor(Color.paper)
        p.contentView = NSHostingView(rootView: AnyView(view))
        p.setContentSize(p.contentView!.fittingSize)
        p.center()
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        panel = p
    }
}
