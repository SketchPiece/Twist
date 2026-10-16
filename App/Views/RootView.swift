import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            switch model.screen {
            case .onboarding: OnboardingView().transition(.opacity)
            case .home: HomeView().transition(.opacity)
            case .locked: LockedView().transition(.opacity)
            case .unwind: UnwindView().transition(.opacity)
            case .opened: OpenedView().transition(.opacity)
            }
        }
        .alert(
            model.hub.request.map { "\($0.device.name) wants to lock together with this iPhone" } ?? "",
            isPresented: Binding(get: { model.hub.request != nil }, set: { if !$0 && model.hub.request?.joining != true { model.hub.decline() } }),
            presenting: model.hub.request
        ) { _ in
            Button("Not now", role: .cancel) { model.hub.decline() }
            Button("Join") { model.hub.accept() }
        } message: { r in
            Text("Code \(r.code). Join only if \(r.device.name) shows the same code.")
        }
        .animation(.smooth(duration: 0.45), value: model.screen)
        .preferredColorScheme(model.screen == .locked || model.screen == .unwind ? .dark : .light)
    }
}
