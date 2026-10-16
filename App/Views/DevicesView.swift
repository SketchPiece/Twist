import SwiftUI

/// The devices sheet from Home: who locks together with this iPhone.
struct DevicesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false

    private var hub: Hub { model.hub }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Devices")
                        .font(.tight(30, .bold))
                        .tracking(-0.9)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.tight(17, .semibold))
                        .opacity(0.55)
                }
                .padding(.top, 24)
                Text("Lock one and they all lock. Unwind one and they all open.")
                    .font(.tight(16))
                    .opacity(0.6)
                    .padding(.top, 6)
                    .padding(.bottom, 20)

                List {
                    Section {
                        ForEach(hub.members) { d in
                            DeviceRow(device: d)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.paperFace)
                                .deleteDisabled(d.id == hub.me.id)
                        }
                        .onDelete { rows in
                            for i in rows { hub.remove(hub.members[i]) }
                        }
                    }
                    Section {
                        Button { adding = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.paper)
                                    .frame(width: 40, height: 40)
                                    .background(Color.graphite, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Add a device").font(.tight(17, .semibold))
                                    Text("Finds Macs and iPads with Twist open nearby")
                                        .font(.tight(14))
                                        .opacity(0.55)
                                }
                            }
                            .frame(height: 68)
                            .padding(.horizontal, 16)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.paperFace)
                    } footer: {
                        Text("Only devices on your Apple ID. Locks go straight over Wi-Fi when the devices are close, and through iCloud when they are not.")
                            .font(.tight(14))
                            .opacity(0.8)
                            .padding(.top, 10)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(14)
                .scrollContentBackground(.hidden)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .contentMargins(.top, 0, for: .scrollContent)
                .padding(.horizontal, -20)
            }
            .padding(.horizontal, 20)
            .foregroundStyle(Color.graphite)
            .background(Color.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $adding) { AddDeviceView() }
        }
        .presentationBackground(Color.paper)
        // Look for devices while the sheet is open, even before the first pairing.
        .onAppear { hub.start() }
        .onDisappear { if !hub.inRing { hub.stop() } }
    }
}

/// Finds Twist nearby, then shows the code to compare, then the result.
struct AddDeviceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var hub: Hub { model.hub }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Add a device").font(.tight(17, .semibold))
                if case .done = hub.pairing {} else {
                    HStack {
                        Button {
                            hub.cancelPairing()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                        .opacity(0.55)
                        .offset(x: -14)
                        Spacer()
                    }
                }
            }
            .frame(height: 44)
            .padding(.top, 8)

            switch hub.pairing {
            case nil, .connecting:
                finding
            case let .code(code, device):
                compare(code: code, device: device)
            case let .done(device):
                joined(device)
            case let .failed(message):
                failed(message)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .foregroundStyle(Color.graphite)
        .background(Color.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.smooth(duration: 0.35), value: hub.pairing)
        .onDisappear {
            if case .done = hub.pairing { hub.pairing = nil }
        }
    }

    private var finding: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            Radar(found: hub.strangers.first?.device)
            Spacer(minLength: 12)
            VStack(spacing: 10) {
                ForEach(hub.strangers) { peer in
                    HStack(spacing: 14) {
                        DeviceTile(device: peer.device)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(peer.device.name).font(.tight(17, .semibold))
                            Text("Twist is open on it").font(.tight(14)).opacity(0.55)
                        }
                        Spacer()
                        if case let .connecting(d) = hub.pairing, d.id == peer.id {
                            ProgressView().frame(width: 64)
                        } else {
                            Button("Add") { hub.add(peer) }
                                .font(.tight(15, .semibold))
                                .foregroundStyle(Color.paper)
                                .padding(.horizontal, 16)
                                .frame(height: 34)
                                .background(Color.graphite, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 72)
                    .background(Color.paperFace, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            Text("Open Twist on the Mac or iPad you want to add. Keep it on the same Wi-Fi.")
                .font(.tight(15))
                .opacity(0.5)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.bottom, 12)
        }
    }

    private func compare(code: String, device: Device) -> some View {
        VStack(spacing: 28) {
            Spacer()
            PairGlyphs(left: hub.me, right: device)
            PairCode(code: code)
            Text("Check that \(device.name) shows the same code, then press **Join** on the \(device.kind == .mac ? "Mac" : device.name).")
                .font(.tight(20))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
            Button("Cancel") {
                hub.cancelPairing()
            }
            .font(.tight(16))
            .opacity(0.45)
            .frame(height: 58)
        }
    }

    private func joined(_ device: Device) -> some View {
        VStack(spacing: 0) {
            Spacer()
            PairGlyphs(left: hub.me, right: device, done: true)
            Text("\(device.name) is in")
                .font(.tight(34, .bold))
                .tracking(-1)
                .padding(.top, 30)
            Text("Next time you twist the dial on either one, both lock. Unwinding on either opens both.")
                .font(.tight(18))
                .opacity(0.6)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 14)
            Spacer()
            PillButton(title: "Done") {
                hub.pairing = nil
                dismiss()
            }
            .padding(.top, 18)
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text(message)
                .font(.tight(20))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
            PillButton(title: "Try again") { hub.pairing = nil }
                .padding(.top, 18)
        }
    }
}

/// Rings around this iPhone with a sweep; a found device sits on the middle ring.
private struct Radar: View {
    var found: Device?
    @State private var sweep = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.graphite.opacity(0.22 - Double(i) * 0.06), lineWidth: 1.4)
                    .frame(width: 140 + CGFloat(i) * 84, height: 140 + CGFloat(i) * 84)
            }
            Wedge(degrees: 50)
                .fill(Color.signal.opacity(0.14))
                .frame(width: 308, height: 308)
                .rotationEffect(.degrees(sweep ? 360 : 0))
                .animation(.linear(duration: 3.2).repeatForever(autoreverses: false), value: sweep)
            Circle()
                .fill(Color.graphite)
                .frame(width: 80, height: 80)
                .overlay(Image(systemName: "iphone").font(.system(size: 30)).foregroundStyle(Color.paper))
            if let found {
                Image(systemName: found.symbol)
                    .font(.system(size: 24))
                    .frame(width: 60, height: 60)
                    .background(Color.paperFace, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.signal, lineWidth: 3))
                    .shadow(color: .black.opacity(0.12), radius: 9, y: 6)
                    .offset(x: 95, y: -59)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 320, height: 320)
        .animation(.spring(duration: 0.4), value: found)
        .onAppear { sweep = true }
    }
}

/// After an unwind in a ring: everything is open, or about to be.
struct OpenedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Wordmark()
                .frame(height: 44)
                .padding(.top, 8)
            Spacer()
            if let by = model.opened?.by {
                Text("Unwound on \(by.name)")
                    .font(.tight(17))
                    .opacity(0.55)
                    .padding(.bottom, 6)
            }
            Text("Open")
                .font(.tight(44, .bold))
                .tracking(-1.8)
            VStack(spacing: 0) {
                ForEach(Array(model.hub.members.enumerated()), id: \.element.id) { i, d in
                    if i > 0 { Divider().opacity(0.6) }
                    HStack(spacing: 14) {
                        DeviceTile(device: d)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(d.name).font(.tight(17, .semibold))
                            HStack(spacing: 6) {
                                let near = d.id == model.hub.me.id || model.hub.isNearby(d.id)
                                StatusDot(kind: near ? .on : .off)
                                Text(near ? "Open" : "Opens as soon as it hears about it")
                            }
                            .font(.tight(14))
                            .opacity(0.55)
                        }
                        Spacer()
                    }
                    .frame(height: 68)
                    .padding(.horizontal, 16)
                }
            }
            .background(Color.paperFace, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.top, 24)
            Text("A device that stays offline still opens on its own when the time runs out.")
                .font(.tight(15))
                .opacity(0.5)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 18)
            Spacer()
            PillButton(title: "Done") { model.closeOpened() }
                .padding(.top, 18)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .foregroundStyle(Color.graphite)
        .background(Color.paper.ignoresSafeArea())
    }
}
