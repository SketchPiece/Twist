import SwiftUI

/// What each screen shows while the Mac is locked. The primary screen has the timer
/// and the unwind; the others just stay quiet behind a lock.
struct LockRoot: View {
    @Environment(MacModel.self) private var model
    var primary: Bool

    var body: some View {
        ZStack {
            if !primary {
                QuietLock()
            } else if let by = model.openedBy {
                OpenedFlash(by: by).transition(.opacity)
            } else if model.unwinding {
                UnwindView().transition(.opacity)
            } else {
                LockedView().transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.45), value: model.unwinding)
        .animation(.smooth(duration: 0.45), value: model.openedBy)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.night)
        .preferredColorScheme(.dark)
    }
}

struct LockedView: View {
    @Environment(MacModel.self) private var model

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

                    if let by = model.lockedBy {
                        Label("Locked from \(by.name)", systemImage: by.symbol)
                            .font(.tight(14))
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Color.paper.opacity(0.08), in: Capsule())
                            .padding(.top, 22)
                    }

                    Button("I need access") { model.openUnwind() }
                        .buttonStyle(.plain)
                        .font(.tight(17))
                        .foregroundStyle(Color.paper.opacity(0.45))
                        .frame(height: 58)
                        .padding(.top, 28)
                        .padding(.bottom, 36)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Color.paper)
    }
}

/// The other screens: no timer to repeat, just a lock.
private struct QuietLock: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 40, weight: .medium))
            .foregroundStyle(Color.paper.opacity(0.18))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Another device unwound the lock: say who, then the lock lets go.
private struct OpenedFlash: View {
    @Environment(MacModel.self) private var model
    var by: Device

    var body: some View {
        VStack(spacing: 0) {
            Text("Unwound on \(by.name)")
                .font(.tight(20, .semibold))
                .opacity(0.6)
            Text("Open")
                .font(.tight(150, .bold))
                .tracking(-7)
                .padding(.top, 10)
            if let s = model.session {
                Text("This Mac is yours again. The lock had \(TimeText.spoken(s.remaining)) left.")
                    .font(.tight(20))
                    .opacity(0.6)
                    .padding(.top, 26)
            }
        }
        .foregroundStyle(Color.graphite)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.signal)
    }
}
