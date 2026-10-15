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

                Button("I need access") { model.openUnwind() }
                    .font(.tight(16))
                    .foregroundStyle(Color.paper.opacity(0.45))
                    .frame(height: 58)
                    .padding(.top, 18)
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
