import SwiftUI

/// Emergency exit: hold the mouse button (or Space) until orange fills the screen.
struct UnwindView: View {
    @Environment(MacModel.self) private var model
    static let duration: TimeInterval = 45

    @State private var progress: Double = 0
    @State private var holding = false
    @State private var holdStart: Date?
    @State private var startProgress: Double = 0
    @FocusState private var focused: Bool

    var body: some View {
        TimelineView(.animation(paused: !holding)) { ctx in
            let p = current(at: ctx.date)
            GeometryReader { geo in
                let fill = geo.size.height * p
                ZStack(alignment: .bottom) {
                    Color.night
                    Color.signal
                        .frame(height: fill)
                        .shadow(color: Color.signal.opacity(p > 0 ? 0.45 : 0), radius: 24)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !holding { begin() } }
                        .onEnded { _ in release() }
                )

                VStack(alignment: .leading, spacing: 0) {
                    Button { model.closeUnwind() } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.tight(17, .semibold))
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(holding ? 0 : 0.55)
                    .padding(.top, 40)

                    readout(p: p)
                        .padding(.top, 40)
                        .allowsHitTesting(false)
                    Spacer()
                }
                .padding(.horizontal, 72)

                thumb(onOrange: fill > 200)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 72)
                    .allowsHitTesting(false)
            }
            .onChange(of: p) { _, value in
                if holding, value >= 1 { finish() }
            }
        }
        .foregroundStyle(Color.paper)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        // Repeats are taken too: left unhandled, each one makes the system beep.
        .onKeyPress(.space, phases: .all) { press in
            if press.phase == .down, !holding { begin() }
            if press.phase == .up { release() }
            return .handled
        }
        .onKeyPress(.escape) {
            guard !holding else { return .ignored }
            model.closeUnwind()
            return .handled
        }
    }

    private func readout(p: Double) -> some View {
        let seconds = Int((Self.duration * (1 - p)).rounded(.up))
        let remaining = model.session?.remaining ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            Text("Session ends on its own in \(TimeText.spoken(remaining))")
                .font(.tight(20))
                .opacity(0.5)
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(AttributedString.tight("\(seconds)", by: -13))
                    .font(.tight(220, .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text("s")
                    .font(.tight(92, .bold))
            }
            .lineLimit(1)
            .padding(.top, 10)
            (Text("left to hold. ").fontWeight(.semibold)
                + Text(model.hub.inRing
                    ? "Keep the mouse button or Space down until the screen is full. Then \(model.hub.names(model.hub.members)) open. Let go and you stay locked."
                    : "Keep the mouse button or Space down until the screen is full. Let go and you stay locked.").foregroundStyle(Color.paper.opacity(0.7)))
                .font(.tight(24))
                .lineSpacing(4)
                .frame(maxWidth: 460, alignment: .leading)
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
            Text(holding ? "Holding" : "Hold the mouse button or Space")
                .font(.tight(17, .semibold))
        }
        .foregroundStyle(ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold the mouse button or Space to unwind")
    }

    private func current(at date: Date) -> Double {
        guard holding, let s = holdStart else { return progress }
        return min(1, startProgress + date.timeIntervalSince(s) / Self.duration)
    }

    private func begin() {
        holding = true
        holdStart = Date()
        startProgress = progress
    }

    private func finish() {
        holding = false
        model.unwind()
    }

    private func release() {
        guard holding else { return }
        progress = current(at: Date())
        holding = false
        holdStart = nil
        // Springs back: letting go keeps you locked.
        withAnimation(.spring(duration: 0.6)) { progress = 0 }
    }
}
