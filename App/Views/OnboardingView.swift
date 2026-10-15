import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            Text("\(step + 1) / 3")
                .font(.tight(17))
                .opacity(0.55)
                .frame(height: 44)
                .padding(.top, 8)

            Group {
                switch step {
                case 0: screenTime
                case 1: vpn
                default: allowlist
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .foregroundStyle(Color.graphite)
        .background(Color.paper.ignoresSafeArea())
        .animation(.smooth(duration: 0.4), value: step)
        .task {
            // Skip what's already granted.
            if AuthorizationCenter.shared.authorizationStatus == .approved {
                step = await VPN.isInstalled ? 2 : 1
            }
        }
    }

    private var screenTime: some View {
        VStack(spacing: 0) {
            Spacer()
            DialFace(minutes: 60).frame(width: 240)
            Spacer()
            heading("Let Twist lock your apps", "Screen Time access stays on this iPhone.")
            errorText
            PillButton(title: "Allow Screen Time") {
                act {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    step = await VPN.isInstalled ? 2 : 1
                }
            }
        }
    }

    private var vpn: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.graphite.opacity(0.06))
                Image(systemName: "wifi.slash")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(Color.signal)
            }
            .frame(width: 168, height: 168)
            Spacer()
            heading("Let Twist cut the internet", "A local VPN that goes nowhere. Nothing leaves your phone.")
            errorText
            PillButton(title: "Allow VPN") {
                act {
                    try await VPN.install()
                    step = 2
                }
            }
        }
    }

    private var allowlist: some View {
        VStack(spacing: 0) {
            heading("What stays open?", "Everything else locks. Calls always work.")
                .padding(.top, 28)
            AllowlistContent()
            PillButton(title: "Done") {
                model.onboarded = true
            }
        }
    }

    private func heading(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.tight(36, .bold))
                .tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
            Text(body)
                .font(.tight(18))
                .opacity(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)
    }

    @ViewBuilder private var errorText: some View {
        if let error {
            Text(error)
                .font(.tight(15))
                .foregroundStyle(Color.signal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)
        }
    }

    private func act(_ work: @escaping () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = nil
        Task {
            do { try await work() } catch { self.error = "Not allowed. Try again." }
            busy = false
        }
    }
}
