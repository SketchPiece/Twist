import FamilyControls
import SwiftUI

/// The apps that stay open during a session.
struct AllowlistContent: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    let apps = Array(model.allowlist.applicationTokens)
                    let categories = Array(model.allowlist.categoryTokens)
                    if apps.isEmpty && categories.isEmpty {
                        Text("Nothing yet")
                            .font(.tight(18))
                            .opacity(0.4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 64)
                    }
                    ForEach(categories, id: \.self) { token in
                        Label(token)
                            .labelStyle(AppRowStyle(note: "All apps"))
                    }
                    ForEach(apps, id: \.self) { token in
                        Label(token)
                            .labelStyle(AppRowStyle())
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Button { picking = true } label: {
                Text(model.allowlist.applicationTokens.isEmpty && model.allowlist.categoryTokens.isEmpty ? "Choose apps" : "Change")
                    .font(.tight(17, .semibold))
                    .foregroundStyle(Color.signal)
                    .frame(height: 50)
            }
            .padding(.bottom, 8)
        }
        .familyActivityPicker(isPresented: $picking, selection: $model.allowlist)
    }
}

private struct AppRowStyle: LabelStyle {
    var note: String?

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            configuration.icon.scaleEffect(1.3).frame(width: 36, height: 36)
            configuration.title.font(.tight(19, .medium)).lineLimit(1)
            Spacer()
            if let note {
                Text(note).font(.tight(16)).opacity(0.4)
            }
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.graphite.opacity(0.1)).frame(height: 1) }
    }
}

struct AllowlistSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What stays open")
                .font(.tight(28, .bold))
                .tracking(-0.8)
                .padding(.top, 28)
            Text("Everything else locks. Calls always work.")
                .font(.tight(17))
                .opacity(0.6)
                .padding(.top, 8)
                .padding(.bottom, 12)
            AllowlistContent()
        }
        .padding(.horizontal, 28)
        .foregroundStyle(Color.graphite)
        .presentationBackground(Color.paper)
    }
}
