import SwiftUI

/// Emergency exit: hold anywhere until orange fills the screen.
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
            let p = current(at: ctx.date)
            GeometryReader { geo in
                let full = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                let fill = full * p
                ZStack(alignment: .bottom) {
                    Color.night
                    Color.signal
                        .frame(height: fill)
                        .shadow(color: Color.signal.opacity(p > 0 ? 0.45 : 0), radius: 24)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !holding { begin() } }
                        .onEnded { _ in release() }
                )

                VStack(alignment: .leading, spacing: 0) {
                    Button { model.closeUnwind() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .opacity(holding ? 0 : 0.55)
                    .offset(x: -14)
                    .padding(.top, 8)

                    readout(p: p)
                        .padding(.top, 22)
                        .allowsHitTesting(false)
                    Spacer()
                }
                .padding(.horizontal, 32)

                thumb(onOrange: fill > geo.safeAreaInsets.bottom + 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 56)
                    .allowsHitTesting(false)
            }
            .onChange(of: p) { _, value in tick(value) }
        }
        .foregroundStyle(Color.paper)
    }

    private func readout(p: Double) -> some View {
        let seconds = Int((Self.duration * (1 - p)).rounded(.up))
        let remaining = model.session?.remaining ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            Text("Session ends on its own in \(TimeText.spoken(remaining))")
                .font(.tight(17))
                .opacity(0.5)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(seconds)")
                    .font(.tight(150, .bold))
                    .tracking(-9)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text("s")
                    .font(.tight(64, .bold))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.top, 10)
            (Text("left to hold. ").fontWeight(.semibold)
                + Text("Keep your thumb down until the screen is full. Let go and you stay locked.").foregroundStyle(Color.paper.opacity(0.7)))
                .font(.tight(20))
                .lineSpacing(3)
                .frame(maxWidth: 300, alignment: .leading)
                .padding(.top, 16)
        }
    }

    private func thumb(onOrange: Bool) -> some View {
        let ink = onOrange ? Color.graphite : Color.paper
        return VStack(spacing: 16) {
            ZStack {
                Circle().strokeBorder(ink, lineWidth: 3)
                Circle().fill(ink.opacity(holding ? 0.18 : 0.08)).padding(13)
            }
            .frame(width: 84, height: 84)
            .scaleEffect(holding ? 0.94 : 1)
            .animation(.spring(duration: 0.3), value: holding)
            Text(holding ? "Holding" : "Hold anywhere")
                .font(.tight(17, .semibold))
        }
        .foregroundStyle(ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold anywhere to unwind")
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
