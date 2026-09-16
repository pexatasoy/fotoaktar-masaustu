import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var account: AccountManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("🐷🌱").font(.system(size: 86))
                    .accessibilityHidden(true)
                    .offset(y: floating && !reduceMotion ? -8 : 8)
                Text("Hayallerine hoş geldin")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Küçük birikimlerin, büyük hayallerin için sıcak bir yuvası olsun.")
                    .font(.title3)
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                Spacer()
                SignInWithAppleButton(.signIn) { _ in
                } onCompletion: { result in
                    Task { @MainActor in account.handle(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                if let message = account.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(Palette.coral)
                }
                Text("Kayıtların cihazında saklanır. iCloud açıksa kendi özel alanında eşitlenir.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink.opacity(0.58))
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
        .alert("Verilerin silindi", isPresented: $account.showRevocationHelp) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text("Apple ile Giriş Yap erişimini de kaldırmak istersen iPhone Ayarlar > adın > Apple ile Giriş Yap > Hedef > Sil yolunu izle.")
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { floating = true }
        }
    }
}
