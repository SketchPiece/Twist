import SwiftUI

struct HomeView: View {
    @Environment(MacModel.self) private var model
    @Environment(Hub.self) private var hub
    @Environment(\.openWindow) private var openWindow
    @State private var minutes = 0

    private var ready: Bool { minutes >= 15 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Wordmark()
                HStack {
                    Button { openWindow(id: "devices") } label: {
                        DevicesButtonLabel(count: hub.members.count)
                            .foregroundStyle(Color.graphite.opacity(0.45))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Devices")
                    .offset(x: -14)
                    Spacer()
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

            PillButton(title: hub.inRing ? "Lock" : "Lock Mac") { model.start(minutes: minutes) }
                .keyboardShortcut(.defaultAction)
                .opacity(ready ? 1 : 0)
                .offset(y: ready ? 0 : 12)
                .allowsHitTesting(ready)
                .animation(.smooth(duration: 0.3), value: ready)
                .padding(.top, 18)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .foregroundStyle(Color.graphite)
        .background(Color.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    private var caption: String {
        let until = TimeText.time(Date().addingTimeInterval(TimeInterval(minutes * 60)))
        return hub.inRing ? "\(hub.names(hub.members)) · until \(until)" : "Mac locked until \(until)"
    }
}
