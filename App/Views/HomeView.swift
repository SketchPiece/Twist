import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var minutes = 0
    @State private var showAllowlist = false
    @State private var showDevices = false
    @State private var starting = false
    @State private var checkingApps = false

    private var ready: Bool { minutes >= 15 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Wordmark()
                HStack {
                    Button { showDevices = true } label: {
                        DevicesButtonLabel(count: model.hub.members.count)
                            .foregroundStyle(Color.graphite.opacity(0.45))
                    }
                    .accessibilityLabel("Devices")
                    Spacer()
                    Button { showAllowlist = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.graphite.opacity(0.45))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("What stays open")
                }
            }
            .frame(height: 44)
            .padding(.top, 8)

            Spacer(minLength: 12)
            TwistDial(minutes: $minutes)
                .padding(.horizontal, 18)
            Spacer(minLength: 12)

            VStack(spacing: 12) {
                Text(TimeText.setting(minutes: minutes))
                    .font(.tight(72, .semibold))
                    .tracking(-2.8)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(minutes)))
                    .animation(.snappy(duration: 0.2), value: minutes)
                Text(ready ? caption : "Twist to set")
                    .font(.tight(17))
                    .opacity(0.55)
            }
            .frame(minHeight: 120)

            PillButton(title: "Lock") {
                guard !starting else { return }
                starting = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                // iOS can't tell us about newly installed apps. Done in the picker
                // re-reads the chosen categories, so they get hidden too.
                if model.hides && model.checksNewApps {
                    checkingApps = true
                } else {
                    lock()
                }
            }
            .opacity(ready ? 1 : 0)
            .offset(y: ready ? 0 : 12)
            .allowsHitTesting(ready)
            .animation(.smooth(duration: 0.3), value: ready)
            .padding(.top, 18)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .foregroundStyle(Color.graphite)
        .background(Color.paper.ignoresSafeArea())
        .familyActivityPicker(
            headerText: "Tap Done to hide apps installed since last time.",
            isPresented: $checkingApps,
            selection: Binding(get: { model.hidden }, set: { model.hidden = $0 })
        )
        .onChange(of: checkingApps) { _, open in
            if !open && starting { lock() }
        }
        .sheet(isPresented: $showDevices) {
            DevicesSheet()
        }
        .sheet(isPresented: $showAllowlist) {
            AllowlistSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private func lock() {
        Task {
            await model.start(minutes: minutes)
            starting = false
        }
    }

    /// "until 15:40", or "iPhone, MacBook Pro and iPad · until 15:40" in a ring.
    private var caption: String {
        let until = "until \(TimeText.time(Date().addingTimeInterval(TimeInterval(minutes * 60))))"
        return model.hub.inRing ? "\(model.hub.names(model.hub.members)) · \(until)" : until
    }
}
