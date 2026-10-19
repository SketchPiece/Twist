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
                    // iOS only lets a shield exempt single apps, and on this phone the picker
                    // hands back a picked category without its apps, so a category alone keeps
                    // nothing open. Say so instead of promising "All apps".
                    ForEach(categories, id: \.self) { token in
                        Label(token)
                            .labelStyle(AppRowStyle(note: "Still locks", warn: true))
                    }
                    ForEach(apps, id: \.self) { token in
                        Label(token)
                            .labelStyle(AppRowStyle())
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            if !model.allowlist.categoryTokens.isEmpty {
                Text("Whole categories can't stay open. Tap Change, open a category and tick the apps inside it.")
                    .font(.tight(15))
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }

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
    var warn = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            // The system draws the icon at the font's size; scaling it afterwards
            // stretches a bitmap and frays its rounded corners.
            configuration.icon.font(.system(size: 30)).frame(width: 36, height: 36)
            configuration.title.font(.tight(19, .medium)).lineLimit(1)
            Spacer()
            if let note {
                Text(note).font(.tight(16))
                    .foregroundStyle(warn ? Color.signal : Color.graphite)
                    .opacity(warn ? 1 : 0.4)
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
