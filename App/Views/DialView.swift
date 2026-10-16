import SwiftUI

/// The Braun-style kitchen timer, flat. One turn = 4 hours; the orange wedge is the time.
struct DialFace: View {
    /// Minutes shown by the wedge (0...240).
    var minutes: Double
    var dark = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let u = side / 280 // drawn on a 280-unit grid, face radius 140
            let tick = dark ? Color.paper : Color.graphite
            ZStack {
                Circle()
                    .fill(dark ? Color.nightFace : Color.paperFace)

                Wedge(degrees: minutes * 1.5)
                    .fill(Color.signal)
                    .padding(16 * u)

                // Hour marks and a dot every 15 minutes.
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    func at(_ r: CGFloat, _ a: Double) -> CGPoint {
                        CGPoint(x: c.x + r * u * sin(a), y: c.y - r * u * cos(a))
                    }
                    for m in stride(from: 0, to: 240, by: 15) {
                        let a = Double(m) * 1.5 * .pi / 180
                        if m % 60 == 0 {
                            var p = Path()
                            p.move(to: at(132, a))
                            p.addLine(to: at(120, a))
                            ctx.stroke(p, with: .color(tick), style: StrokeStyle(lineWidth: 3 * u, lineCap: .round))
                        } else {
                            let p = at(130, a), r = 1.6 * u
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                                     with: .color(tick.opacity(0.35)))
                        }
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
                Circle().fill(dark ? Color(white: 0.16) : Color.graphite)
                Capsule()
                    .fill(Color.signal)
                    .frame(width: s * 0.055, height: s * 0.42)
                    .offset(y: -s * 0.18)
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
