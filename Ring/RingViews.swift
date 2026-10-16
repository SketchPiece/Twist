import SwiftUI

extension Device {
    var symbol: String {
        switch kind {
        case .phone: "iphone"
        case .pad: "ipad"
        case .mac: name.contains("Book") ? "laptopcomputer" : "desktopcomputer"
        }
    }
}

/// Filled: reachable now. Hollow: not nearby. Orange: locked in this session.
struct StatusDot: View {
    enum Kind { case on, off, lock }
    var kind: Kind
    var color: Color = .graphite

    var body: some View {
        Group {
            switch kind {
            case .on: Circle().fill(color)
            case .lock: Circle().fill(Color.signal)
            case .off: Circle().strokeBorder(color.opacity(0.45), lineWidth: 1.5)
            }
        }
        .frame(width: 8, height: 8)
    }
}

struct DeviceTile: View {
    var device: Device
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: device.symbol)
            .font(.system(size: size * 0.45, weight: .regular))
            .frame(width: size, height: size)
            .background(Color.graphite.opacity(0.06), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

struct DeviceRow<Trailing: View>: View {
    @Environment(Hub.self) private var hub
    var device: Device
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            DeviceTile(device: device)
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name).font(.tight(17, .semibold))
                HStack(spacing: 6) {
                    StatusDot(kind: device.id == hub.me.id || hub.isNearby(device.id) ? .on : .off)
                    Text(hub.status(of: device))
                }
                .font(.tight(14))
                .opacity(0.55)
            }
            Spacer(minLength: 8)
            trailing
        }
        .frame(height: 68)
        .padding(.horizontal, 16)
    }
}

extension DeviceRow where Trailing == EmptyView {
    init(device: Device) {
        self.init(device: device) { EmptyView() }
    }
}

/// The two devices being paired, joined by a dashed line (solid orange once joined).
struct PairGlyphs: View {
    var left: Device
    var right: Device
    var done = false

    var body: some View {
        HStack(spacing: 14) {
            tile(left)
            Rectangle()
                .fill(.clear)
                .frame(width: 72, height: 3)
                .overlay {
                    if done {
                        Capsule().fill(Color.signal)
                    } else {
                        Line().stroke(Color.graphite.opacity(0.3), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
                    }
                }
            tile(right)
        }
    }

    private func tile(_ d: Device) -> some View {
        Image(systemName: d.symbol)
            .font(.system(size: 30))
            .frame(width: 72, height: 72)
            .background(Color.paperFace, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(done ? Color.signal : Color.graphite.opacity(0.08), lineWidth: done ? 3 : 1)
            }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: 0, y: rect.midY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

/// "4 7 1 9", one digit per card.
struct PairCode: View {
    var code: String
    var size: CGFloat = 68

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(code.enumerated()), id: \.offset) { _, d in
                Text(String(d))
                    .font(.tight(size, .bold))
                    .monospacedDigit()
                    .frame(width: size * 0.82, height: size * 1.25)
                    .background(Color.paperFace, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.graphite.opacity(0.08)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Code \(code.map(String.init).joined(separator: " "))")
    }
}

/// The devices button on Home: overlapping devices with the count.
struct DevicesButtonLabel: View {
    var count: Int

    var body: some View {
        Image(systemName: "rectangle.on.rectangle")
            .font(.system(size: 17, weight: .medium))
            .frame(width: 44, height: 44)
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.paper)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.graphite, in: Capsule())
                        .offset(x: -3, y: 5)
                }
            }
    }
}
