import SwiftUI
import AuthenticationServices
import CryptoKit

struct OnboardingView: View {
    @ObservedObject private var auth = SupabaseService.shared
    @State private var isSigningInGoogle = false
    @State private var isSigningInApple = false
    @State private var errorMessage: String?

    // Held across ASAuthorizationAppleIDRequest → onCompletion so nonces match.
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                VStack(spacing: 12) {
                    Text("BeFree")
                        .font(.largeTitle.bold())

                    Text("Block apps you're trying to avoid and send the unlock code to a trusted friend. You can't undo it yourself.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 16) {
                    featureRow(icon: "hand.raised.fill", color: .red,
                               title: "You block yourself",
                               detail: "Pick an app and lock it down.")
                    featureRow(icon: "envelope.fill", color: .blue,
                               title: "A friend holds the code",
                               detail: "They get the 4-digit unlock code by email.")
                    featureRow(icon: "stopwatch.fill", color: .orange,
                               title: "See how long you've stayed clean",
                               detail: "A live timer tracks your streak.")
                }
                .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Sign in with Apple — Apple's official button, required by App Store guideline 4.8
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    Task { await handleAppleResult(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .disabled(isSigningInApple || isSigningInGoogle)
                .opacity((isSigningInApple || isSigningInGoogle) ? 0.6 : 1)

                googleSignInButton

                Text("Screen Time permission will be requested when you block your first app.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Google button

    private var googleSignInButton: some View {
        Button {
            Task { await signInWithGoogle() }
        } label: {
            HStack(spacing: 12) {
                if isSigningInGoogle {
                    ProgressView()
                        .tint(.secondary)
                        .frame(width: 20, height: 20)
                } else {
                    googleLogo
                }
                Text(isSigningInGoogle ? "Signing in…" : "Sign in with Google")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .disabled(isSigningInGoogle || isSigningInApple)
        .padding(.horizontal, 24)
    }

    private var googleLogo: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
            Text("G")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.26, green: 0.52, blue: 0.96),
                                 Color(red: 0.92, green: 0.26, blue: 0.21)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Feature rows

    private func featureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func signInWithGoogle() async {
        isSigningInGoogle = true
        errorMessage = nil
        do {
            try await SupabaseService.shared.signInWithGoogle()
        } catch {
            errorMessage = "Sign in failed. Please try again."
        }
        isSigningInGoogle = false
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Sign in failed. Please try again."
                return
            }
            isSigningInApple = true
            errorMessage = nil
            do {
                try await SupabaseService.shared.signInWithApple(idToken: idToken, nonce: nonce)
            } catch {
                errorMessage = "Sign in failed. Please try again."
            }
            isSigningInApple = false

        case .failure(let error):
            // ASAuthorizationError.canceled means the user dismissed the sheet — not an error.
            let code = (error as? ASAuthorizationError)?.code
            if code != .canceled {
                errorMessage = "Sign in failed. Please try again."
            }
        }
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    OnboardingView()
}
