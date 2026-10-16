import SwiftUI

struct LockedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = model.session.map { max(0, $0.end.timeIntervalSince(ctx.date)) } ?? 0
            VStack(spacing: 0) {
                Wordmark(color: .paper)
                    .opacity(0.5)
                    .frame(height: 44)
                    .padding(.top, 8)

                Spacer(minLength: 12)
                DialFace(minutes: remaining / 60, dark: true)
                    .padding(.horizontal, 18)
                    .animation(.linear(duration: 1), value: remaining)
                Spacer(minLength: 12)

                VStack(spacing: 12) {
                    Text(TimeText.clock(remaining))
                        .font(.tight(72, .semibold))
                        .tracking(-2.8)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if let end = model.session?.end {
                        Text("opens at \(TimeText.time(end))")
                            .font(.tight(17))
                            .opacity(0.55)
                    }
                }
                .frame(minHeight: 120)

                if model.hub.inRing {
                    AlsoLocked()
                        .padding(.top, 14)
                }

                Button("I need access") { model.openUnwind() }
                    .font(.tight(16))
                    .foregroundStyle(Color.paper.opacity(0.45))
                    .frame(height: 58)
                    .padding(.top, model.hub.inRing ? 6 : 18)
            }
            .onChange(of: remaining <= 0) { _, over in
                if over { model.end() }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .foregroundStyle(Color.paper)
        .background(Color.night.ignoresSafeArea())
    }
}

/// The other devices in this lock: "● MacBook Pro | ● iPad".
private struct AlsoLocked: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 7) {
            if let by = model.lockedBy {
                Image(systemName: by.symbol).font(.system(size: 13))
                Text("Locked from \(by.name)")
            } else {
                ForEach(Array(model.hub.others.enumerated()), id: \.element.id) { i, d in
                    if i > 0 { Rectangle().frame(width: 1, height: 12).opacity(0.15).padding(.horizontal, 3) }
                    StatusDot(kind: .lock)
                    Text(d.name)
                }
            }
        }
        .font(.tight(14))
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Color.paper.opacity(0.08), in: Capsule())
    }
}
