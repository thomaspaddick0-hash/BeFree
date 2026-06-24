import SwiftUI
import AuthenticationServices
import CryptoKit

struct OnboardingView: View {
    @ObservedObject private var auth = SupabaseService.shared
    @State private var isSigningInGoogle = false
    @State private var isSigningInApple = false
    @State private var isSubmittingEmail = false
    @State private var errorMessage: String?
    @State private var email = ""
    @State private var password = ""
    @State private var isEmailSignUp = false

    // Held across ASAuthorizationAppleIDRequest → onCompletion so nonces match.
    @State private var currentNonce: String?

    private var isBusy: Bool { isSigningInApple || isSigningInGoogle || isSubmittingEmail }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    signInCard
                    loginCard
                    permissionNote
                }
                .frame(maxWidth: 460)
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity, minHeight: cardMinHeight)
            }
        }
    }

    private var cardMinHeight: CGFloat {
        UIScreen.main.bounds.height - 40
    }

    // MARK: - Card

    private var signInCard: some View {
        VStack(spacing: 24) {
            BeFreeWordmark(style: .hero, color: .green)
                .padding(.top, 8)

            Text("Block the apps you can't put down — a friend holds the key.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
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
                .frame(height: 52)
                .cornerRadius(12)
                .disabled(isBusy)
                .opacity(isBusy ? 0.6 : 1)

                orDivider

                googleSignInButton
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    private var loginCard: some View {
        VStack(spacing: 16) {
            Text("Log in")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            authTextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            authTextField("Password", text: $password, secure: true)
                .textContentType(isEmailSignUp ? .newPassword : .password)

            Button {
                Task { await submitEmailAuth() }
            } label: {
                Group {
                    if isSubmittingEmail {
                        ProgressView().tint(.white)
                    } else {
                        Text(isEmailSignUp ? "Sign up" : "Log in")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!canSubmitEmail || isBusy)
            .opacity(canSubmitEmail && !isBusy ? 1 : 0.6)

            Button {
                isEmailSignUp.toggle()
                errorMessage = nil
            } label: {
                Text(isEmailSignUp
                     ? "Already have an account? Log in"
                     : "Don't have an account? Sign up")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    private func authTextField(_ placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private var canSubmitEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && password.count >= 6
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
            Text("OR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
        }
    }

    private var permissionNote: some View {
        Text("Screen Time permission will be requested when you block your first app.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
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
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
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

    // MARK: - Actions

    private func signInWithGoogle() async {
        isSigningInGoogle = true
        errorMessage = nil
        do {
            try await SupabaseService.shared.signInWithGoogle()
        } catch is CancellationError {
            // User dismissed the web auth sheet — not an error.
        } catch {
            errorMessage = friendlyError(error)
        }
        isSigningInGoogle = false
    }

    private func submitEmailAuth() async {
        isSubmittingEmail = true
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        do {
            if isEmailSignUp {
                try await SupabaseService.shared.signUpWithEmail(email: trimmedEmail, password: password)
            } else {
                try await SupabaseService.shared.signInWithEmail(email: trimmedEmail, password: password)
            }
        } catch {
            errorMessage = friendlyError(error)
        }
        isSubmittingEmail = false
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
                errorMessage = friendlyError(error)
            }
            isSigningInApple = false

        case .failure(let error):
            // ASAuthorizationError.canceled means the user dismissed the sheet — not an error.
            let code = (error as? ASAuthorizationError)?.code
            if code != .canceled {
                errorMessage = friendlyError(error)
            }
        }
    }

    /// Surfaces the underlying reason so dashboard/config problems are visible during testing.
    private func friendlyError(_ error: Error) -> String {
        "Sign in failed: \(error.localizedDescription)"
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
