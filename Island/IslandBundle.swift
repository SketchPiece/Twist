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
                DynamicIslandExpandedRegion(.leading) {
                    MiniDial(state: s, over: over)
                        .frame(width: 58, height: 58)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Wordmark(size: 15, color: .paper)
                        .opacity(0.45)
                        .padding(.trailing, 6)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Countdown(state: s, over: over, size: 40)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 6)
                        .padding(.top, 2)
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
                .opacity(0.4)
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

/// The kitchen timer, small: night face, hour marks, an orange arc for the time left
/// out of 4 hours, and the graphite knob. `bare` drops the face and marks for the island.
private struct MiniDial: View {
    var state: LockAttributes.ContentState
    var over: Bool
    var bare = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if !bare {
                    Circle().fill(Color.nightFace)
                    Canvas { ctx, size in
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        let r = side / 2
                        for h in 0..<4 {
                            let a = Double(h) * .pi / 2
                            var p = Path()
                            p.move(to: CGPoint(x: c.x + r * 0.94 * sin(a), y: c.y - r * 0.94 * cos(a)))
                            p.addLine(to: CGPoint(x: c.x + r * 0.84 * sin(a), y: c.y - r * 0.84 * cos(a)))
                            ctx.stroke(p, with: .color(Color.paper.opacity(0.5)),
                                       style: StrokeStyle(lineWidth: max(1.5, side * 0.025), lineCap: .round))
                        }
                    }
                }

                if over {
                    Circle()
                        .strokeBorder(Color.paper.opacity(0.18), lineWidth: bare ? 2.5 : side * 0.06)
                        .padding(bare ? 0 : side * 0.2)
                } else {
                    ProgressView(timerInterval: state.dialRange, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.circular)
                    .tint(Color.signal)
                    .padding(bare ? 0 : side * 0.17)
                }

                Circle()
                    .fill(bare ? Color.signal : Color.graphite)
                    .frame(width: side * (bare ? 0.26 : 0.34))
                    .overlay {
                        if !bare {
                            Circle().fill(Color.signal).frame(width: side * 0.07)
                        }
                    }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
