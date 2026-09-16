import AuthenticationServices
import Combine
import Foundation
import Security

@MainActor
final class AccountManager: ObservableObject {
    static let shared = AccountManager()
    @Published private(set) var signedIn = false
    @Published private(set) var errorMessage: String?
    @Published var showRevocationHelp = false

    private let key = "com.hedefapp.hedef.apple-user-id"

    private init() {
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
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        signedIn = false
        GoalStore.shared.stopSync()
    }

    func deleteAccount() async throws {
        try await GoalStore.shared.deleteAccountData()
        signOut()
        showRevocationHelp = true
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
