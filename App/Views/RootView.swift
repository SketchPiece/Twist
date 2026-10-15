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
            }
        }
        .animation(.smooth(duration: 0.45), value: model.screen)
        .preferredColorScheme(model.screen == .locked || model.screen == .unwind ? .dark : .light)
    }
}
