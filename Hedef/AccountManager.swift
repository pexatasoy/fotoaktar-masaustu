import AuthenticationServices
import Combine
import Foundation
import Security

@MainActor
final class AccountManager: ObservableObject {
    static let shared = AccountManager()
    @Published private(set) var signedIn = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLocalDemo = false
    @Published var showRevocationHelp = false

    private let key = "com.hedefapp.hedef.apple-user-id"
    private let localDemoKey = "com.hedefapp.hedef.local-demo-enabled"

    private init() {
        #if HEDEF_LOCAL_ONLY
        if UserDefaults.standard.bool(forKey: localDemoKey) {
            isLocalDemo = true
            signedIn = true
            GoalStore.shared.activate(userID: "local-demo")
            return
        }
        #endif
        if let userID = readUserID() {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { [weak self] state, _ in
                Task { @MainActor in
                    if state == .authorized {
                        GoalStore.shared.activate(userID: userID)
                        self?.signedIn = true
                    } else {
                        self?.signOut()
                    }
                }
            }
        }
    }

    #if HEDEF_LOCAL_ONLY
    func continueLocally() {
        UserDefaults.standard.set(true, forKey: localDemoKey)
        isLocalDemo = true
        errorMessage = nil
        GoalStore.shared.activate(userID: "local-demo")
        signedIn = true
    }
    #endif

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple hesabı doğrulanamadı."
                return
            }
            guard saveUserID(credential.user) else {
                errorMessage = "Hesap bu cihazda güvenle saklanamadı. Lütfen yeniden dene."
                return
            }
            signedIn = true
            errorMessage = nil
            GoalStore.shared.activate(userID: credential.user)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        #if HEDEF_LOCAL_ONLY
        UserDefaults.standard.removeObject(forKey: localDemoKey)
        isLocalDemo = false
        #endif
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        signedIn = false
        GoalStore.shared.stopSync()
    }

    func deleteAccount() async throws {
        try await GoalStore.shared.deleteAccountData()
        let wasLocalDemo = isLocalDemo
        signOut()
        showRevocationHelp = !wasLocalDemo
    }

    func handleCredentialRevocation() {
        guard !isLocalDemo else { return }
        signOut()
    }

    private func readUserID() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveUserID(_ userID: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        let item: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrAccount as String: key,
                                   kSecValueData as String: Data(userID.utf8),
                                   kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}
