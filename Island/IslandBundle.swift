import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IslandBundle: WidgetBundle {
    var body: some Widget {
        LockActivity()
    }
}

struct LockActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockAttributes.self) { context in
            LockScreenView(state: context.state, over: context.isStale)
                .activityBackgroundTint(Color.night)
                .activitySystemActionForegroundColor(Color.paper)
        } dynamicIsland: { context in
            let s = context.state, over = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 16) {
                        MiniDial(state: s, over: over)
                            .frame(width: 64, height: 64)
                        Countdown(state: s, over: over, size: 40)
                        Spacer(minLength: 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        Wordmark(size: 14, color: .paper)
                            .opacity(0.5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                MiniDial(state: s, over: over, bare: true)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                CompactTime(state: s, over: over)
            } minimal: {
                MiniDial(state: s, over: over, bare: true)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(Color.signal)
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    var state: LockAttributes.ContentState
    var over: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            MiniDial(state: state, over: over)
                .frame(width: 76, height: 76)
            Countdown(state: state, over: over, size: 44)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .topTrailing) {
            Wordmark(size: 15, color: .paper)
                .opacity(0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .foregroundStyle(Color.paper)
    }
}

/// "1:12:08" over "opens at 14:30", or "Open" once the time is up.
private struct Countdown: View {
    var state: LockAttributes.ContentState
    var over: Bool
    var size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if over {
                Text("Open")
                    .font(.tight(size, .semibold))
                    .tracking(-size * 0.035)
                Text("Time's up. Open Twist to switch the internet back on.")
                    .font(.tight(14))
                    .opacity(0.55)
                    .lineLimit(2)
            } else {
                Text(timerInterval: state.countdown, countsDown: true)
                    .font(.tight(size, .semibold))
                    .tracking(-size * 0.035)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Group {
                    if let by = state.lockedBy {
                        Text("opens at \(TimeText.time(state.end)) · from \(by)")
                    } else {
                        Text("opens at \(TimeText.time(state.end))")
                    }
                }
                .font(.tight(15))
                .opacity(0.55)
                .lineLimit(1)
            }
        }
        .foregroundStyle(Color.paper)
    }
}

/// Just the time, in orange, next to the camera.
private struct CompactTime: View {
    var state: LockAttributes.ContentState
    var over: Bool

    var body: some View {
        Group {
            if over {
                Text("Open")
            } else {
                // The timer text reserves its widest width; pin it so it hugs the camera.
                Text(timerInterval: state.countdown, countsDown: true)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(width: state.end.timeIntervalSinceNow >= 3600 ? 58 : 42, alignment: .trailing)
            }
        }
        .font(.tight(15, .semibold))
        .foregroundStyle(Color.signal)
    }
}

// MARK: - The dial

/// A clock that runs out: twelve marks around the edge and an orange slice for the time
/// left out of 4 hours, shrinking back to 12 o'clock. `bare` drops the marks for the island.
private struct MiniDial: View {
    var state: LockAttributes.ContentState
    var over: Bool
    var bare = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inset = bare ? 0 : side * 0.1
            ZStack {
                if !bare {
                    Canvas { ctx, size in
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        let r = side / 2
                        for h in 0..<12 {
                            let a = Double(h) * .pi / 6
                            let inner = r - side * (h % 3 == 0 ? 0.09 : 0.05)
                            var p = Path()
                            p.move(to: CGPoint(x: c.x + (r - 0.5) * sin(a), y: c.y - (r - 0.5) * cos(a)))
                            p.addLine(to: CGPoint(x: c.x + inner * sin(a), y: c.y - inner * cos(a)))
                            ctx.stroke(p, with: .color(Color.paper.opacity(0.5)),
                                       style: StrokeStyle(lineWidth: max(1, side * 0.025)))
                        }
                    }
                }

                Circle()
                    .fill(Color.paper.opacity(bare ? 0.18 : 0.06))
                    .padding(inset)

                if !over {
                    TimerWedge(range: state.dialRange, side: side - inset * 2)
                        .padding(inset)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A Live Activity can only animate the system's timer ring, so the slice is that ring
/// nested inside itself until the rings overlap into a solid wedge.
private struct TimerWedge: View {
    var range: ClosedRange<Date>
    var side: CGFloat

    var body: some View {
        let step: CGFloat = 2.5
        let rings = max(2, Int(side / 2 / step))
        ZStack {
            ForEach(0..<rings, id: \.self) { i in
                ProgressView(timerInterval: range, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(Color.signal)
                .padding(CGFloat(i) * step)
            }
        }
    }
}
