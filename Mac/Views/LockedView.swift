import SwiftUI

/// What each screen shows while the Mac is locked. Only the primary screen can unwind.
struct LockRoot: View {
    @Environment(MacModel.self) private var model
    var primary: Bool

    var body: some View {
        ZStack {
            if primary && model.unwinding {
                UnwindView().transition(.opacity)
            } else {
                LockedView(primary: primary).transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.45), value: model.unwinding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.night)
        .preferredColorScheme(.dark)
    }
}

struct LockedView: View {
    @Environment(MacModel.self) private var model
    var primary: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = model.session.map { max(0, $0.end.timeIntervalSince(ctx.date)) } ?? 0
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Wordmark(size: 26, color: .paper)
                        .opacity(0.5)
                        .padding(.top, 40)

                    Spacer(minLength: 24)
                    DialFace(minutes: remaining / 60, dark: true)
                        .frame(height: geo.size.height * 0.48)
                        .animation(.linear(duration: 1), value: remaining)
                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        Text(TimeText.clock(remaining))
                            .font(.tight(96, .semibold))
                            .tracking(-3.6)
                            .monospacedDigit()
                        if let end = model.session?.end {
                            Text("opens at \(TimeText.time(end))")
                                .font(.tight(20))
                                .opacity(0.55)
                        }
                    }

                    Button("I need access") { model.openUnwind() }
                        .buttonStyle(.plain)
                        .font(.tight(17))
                        .foregroundStyle(Color.paper.opacity(0.45))
                        .frame(height: 58)
                        .padding(.top, 28)
                        .padding(.bottom, 36)
                        .opacity(primary ? 1 : 0)
                        .allowsHitTesting(primary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Color.paper)
    }
}
