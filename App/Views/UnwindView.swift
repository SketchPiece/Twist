import SwiftUI

/// Emergency exit: hold until the dial runs back to zero.
struct UnwindView: View {
    @Environment(AppModel.self) private var model
    static let duration: TimeInterval = 45

    @State private var progress: Double = 0
    @State private var holding = false
    @State private var holdStart: Date?
    @State private var startProgress: Double = 0
    @State private var lastBuzz = 0

    var body: some View {
        TimelineView(.animation(paused: !holding)) { ctx in
            let remaining = model.session?.remaining ?? 0
            let p = current(at: ctx.date)
            VStack(spacing: 0) {
                HStack {
                    Button { model.closeUnwind() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .opacity(holding ? 0 : 0.6)
                    Spacer()
                    Text(holding ? "Keep holding" : "Hold to unwind")
                        .font(.tight(17))
                        .opacity(0.8)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .frame(height: 44)
                .padding(.top, 8)

                Spacer(minLength: 12)
                DialFace(minutes: remaining / 60 * (1 - p), dark: true)
                    .padding(.horizontal, 40)
                Spacer(minLength: 12)

                VStack(spacing: 12) {
                    Text(TimeText.clock(max(0, Self.duration * (1 - p))))
                        .font(.tight(64, .semibold))
                        .tracking(-2.4)
                        .monospacedDigit()
                        .foregroundStyle(holding ? Color.signal : Color.paper)
                    Text(holding ? "Let go to stay locked" : "Your session ends if you get to zero")
                        .font(.tight(17))
                        .opacity(0.55)
                }
                .frame(minHeight: 110)

                HoldButton(progress: p, holding: holding)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in if !holding { begin() } }
                            .onEnded { _ in release() }
                    )
                    .padding(.top, 8)
            }
            .onChange(of: p) { _, value in tick(value) }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .foregroundStyle(Color.paper)
        .background(Color.night.ignoresSafeArea())
    }

    private func current(at date: Date) -> Double {
        guard holding, let s = holdStart else { return progress }
        return min(1, startProgress + date.timeIntervalSince(s) / Self.duration)
    }

    private func begin() {
        holding = true
        holdStart = Date()
        startProgress = progress
        lastBuzz = Int(progress * 9)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func tick(_ p: Double) {
        guard holding else { return }
        let step = Int(p * 9) // a soft knock every 5 s
        if step != lastBuzz {
            lastBuzz = step
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        if p >= 1 {
            holding = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            model.end()
        }
    }

    private func release() {
        guard holding else { return }
        progress = current(at: Date())
        holding = false
        holdStart = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Springs back: letting go keeps you locked.
        withAnimation(.spring(duration: 0.6)) { progress = 0 }
    }
}

private struct HoldButton: View {
    var progress: Double
    var holding: Bool

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.16))
            Circle().stroke(Color.paper.opacity(0.14), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.signal, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("Hold")
                .font(.tight(17, .semibold))
        }
        .frame(width: 112, height: 112)
        .scaleEffect(holding ? 0.94 : 1)
        .animation(.spring(duration: 0.3), value: holding)
        .contentShape(Circle())
        .accessibilityLabel("Hold to unwind")
    }
}
