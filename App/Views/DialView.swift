import SwiftUI

/// The Braun-style kitchen timer. One turn = 4 hours; the orange wedge is the time.
struct DialFace: View {
    /// Minutes shown by the wedge (0...240).
    var minutes: Double
    var dark = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let u = side / 300 // drawn on a 300-unit grid
            let tick = dark ? Color.paper : Color.graphite
            ZStack {
                Circle()
                    .fill(dark ? Color.nightFace : Color.paperFace)
                    .shadow(color: .black.opacity(dark ? 0.5 : 0.10), radius: 0, x: 0, y: 6 * u)

                Wedge(degrees: minutes * 1.5)
                    .fill(Color.signal)
                    .padding(32 * u)

                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = 140 * u
                    for m in stride(from: 0, to: 240, by: 5) {
                        let major = m % 60 == 0, mid = m % 15 == 0
                        let a = Double(m) * 1.5 * .pi / 180
                        let outer = r - 4 * u, inner = r - (major ? 20 : mid ? 13 : 9) * u
                        var p = Path()
                        p.move(to: CGPoint(x: c.x + outer * sin(a), y: c.y - outer * cos(a)))
                        p.addLine(to: CGPoint(x: c.x + inner * sin(a), y: c.y - inner * cos(a)))
                        ctx.stroke(p, with: .color(tick.opacity(major ? 1 : mid ? 0.7 : 0.35)),
                                   style: StrokeStyle(lineWidth: (major ? 3 : mid ? 2 : 1.2) * u, lineCap: .round))
                    }
                    for h in 0..<4 {
                        let a = Double(h) * 90 * .pi / 180
                        let rr = r - 40 * u
                        let text = ctx.resolve(Text("\(h)").font(.tight(22 * u, .semibold)).foregroundStyle(tick))
                        ctx.draw(text, at: CGPoint(x: c.x + rr * sin(a), y: c.y - rr * cos(a)))
                    }
                }

                Knob(degrees: minutes * 1.5, dark: dark)
                    .frame(width: 92 * u, height: 92 * u)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct Knob: View {
    var degrees: Double
    var dark: Bool

    var body: some View {
        GeometryReader { g in
            let s = g.size.width
            ZStack {
                Circle().fill(.black.opacity(0.18)).offset(y: s * 0.035)
                Circle().fill(dark ? Color(white: 0.16) : Color.graphite)
                Circle().fill(RadialGradient(colors: [.white.opacity(0.18), .clear],
                                             center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: s * 0.7))
                Capsule()
                    .fill(Color.signal)
                    .frame(width: s * 0.055, height: s * 0.44)
                    .offset(y: -s * 0.22)
                    .rotationEffect(.degrees(degrees))
            }
        }
    }
}

/// The dial you can turn. Snaps to 5 minutes, ticks under the finger.
struct TwistDial: View {
    @Binding var minutes: Int
    var onRelease: () -> Void = {}

    @State private var angle: Double = 0 // continuous, 0...360
    @State private var last: Double?
    @State private var turning = false
    private let haptic = Tick()

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            DialFace(minutes: turning ? angle / 1.5 : Double(minutes))
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let dx = v.location.x - c.x, dy = v.location.y - c.y
                            guard hypot(dx, dy) > 24 else { last = nil; return }
                            var a = atan2(dx, -dy) * 180 / .pi
                            if a < 0 { a += 360 }
                            if !turning {
                                turning = true
                                angle = Double(minutes) * 1.5
                                haptic.prepare()
                            }
                            if let l = last {
                                var d = a - l
                                if d > 180 { d -= 360 }
                                if d < -180 { d += 360 }
                                angle = min(360, max(0, angle + d))
                            }
                            last = a
                            let snapped = Int((angle / 1.5 / 5).rounded()) * 5
                            if snapped != minutes {
                                minutes = snapped
                                haptic.selectionChanged()
                            }
                        }
                        .onEnded { _ in
                            last = nil
                            // Sessions are 15 min to 4 h.
                            var m = minutes
                            if m > 0 && m < 15 { m = m < 8 ? 0 : 15 }
                            if m != minutes { haptic.snap() }
                            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                                minutes = m
                                turning = false
                            }
                            onRelease()
                        }
                )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Timer")
        .accessibilityValue(TimeText.setting(minutes: minutes))
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: minutes = min(240, max(15, minutes + 15))
            case .decrement: minutes = max(0, minutes - 15 < 15 ? 0 : minutes - 15)
            @unknown default: break
            }
        }
    }
}

/// Dial clicks: haptics on the phone, the trackpad on the Mac.
private struct Tick {
    #if os(iOS)
    private let selection = UISelectionFeedbackGenerator()
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    func prepare() { selection.prepare() }
    func selectionChanged() { selection.selectionChanged() }
    func snap() { rigid.impactOccurred() }
    #else
    func prepare() {}
    func selectionChanged() { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
    func snap() { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
    #endif
}
