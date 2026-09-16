import SwiftUI
import AuthenticationServices

@main
struct HedefApp: App {
    @StateObject private var store = GoalStore.shared
    @StateObject private var account = AccountManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if account.signedIn { RootView() }
                else { WelcomeView() }
            }
            .environmentObject(store)
            .environmentObject(account)
            .foregroundStyle(Palette.ink)
            .onChange(of: scenePhase) { phase in
                if phase == .active && account.signedIn { store.syncNow() }
            }
            .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
                account.handleCredentialRevocation()
            }
        }
    }
}
