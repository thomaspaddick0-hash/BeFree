import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - Theme

private enum AuthTheme {
    static let brandBlue = Color(red: 0.10, green: 0.14, blue: 0.49) // #1A237E
}

// MARK: - Onboarding

struct OnboardingView: View {
    @ObservedObject private var auth = SupabaseService.shared

    @State private var screen: Screen = .splash
    @State private var isSigningInGoogle = false
    @State private var isSigningInApple = false
    @State private var isSubmittingEmail = false
    @State private var errorMessage: String?
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var currentNonce: String?

    private enum Screen {
        case splash, signUp, login
    }

    private var isBusy: Bool { isSigningInApple || isSigningInGoogle || isSubmittingEmail }

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                splashScreen
                    .transition(.opacity)
            case .signUp, .login:
                authScreen
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: screen)
    }

    // MARK: - Splash

    private var splashScreen: some View {
        AuthTheme.brandBlue
            .ignoresSafeArea()
            .overlay {
                BeFreeWordmark(
                    style: .horizontalHero,
                    color: .white,
                    textColor: .white
                )
            }
            .onAppear {
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    screen = .signUp
                }
            }
    }

    // MARK: - Auth screens

    private var authScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                if screen == .signUp {
                    HStack {
                        Button { goToLogin() } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(8)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

                BeFreeWordmark(
                    style: .horizontalHero,
                    color: AuthTheme.brandBlue,
                    textColor: AuthTheme.brandBlue
                )

                VStack(spacing: 20) {
                    Text(screen == .signUp ? "Create your Account" : "Login to your Account")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    authTextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    authTextField("Password", text: $password, secure: true)
                        .textContentType(screen == .signUp ? .newPassword : .password)

                    if screen == .signUp {
                        authTextField("Confirm Password", text: $confirmPassword, secure: true)
                            .textContentType(.newPassword)
                    }

                    primaryButton(
                        screen == .signUp ? "Sign up" : "Sign in",
                        enabled: screen == .signUp ? canSubmitSignUp : canSubmitLogin
                    ) {
                        Task { await submitEmailAuth() }
                    }

                    socialDivider(screen == .signUp ? "Or sign up with" : "Or sign in with")

                    socialButtonsRow
                }

                if screen == .login {
                    Button { goToSignUp() } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(.secondary)
                            Text("Sign up")
                                .fontWeight(.semibold)
                                .foregroundStyle(AuthTheme.brandBlue)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 8)
                } else {
                    Button { goToLogin() } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundStyle(.secondary)
                            Text("Log in")
                                .fontWeight(.semibold)
                                .foregroundStyle(AuthTheme.brandBlue)
                        }
                        .font(.subheadline)
                    }
                    .padding(.top, 8)
                }

                Text("Screen Time permission will be requested when you block your first app.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity, minHeight: UIScreen.main.bounds.height - 20)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Components

    private func authTextField(_ placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isSubmittingEmail {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AuthTheme.brandBlue)
            )
        }
        .disabled(!enabled || isBusy)
        .opacity(enabled && !isBusy ? 1 : 0.55)
    }

    private func socialDivider(_ label: String) -> some View {
        HStack(spacing: 12) {
            line
            Text("- \(label) -")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(height: 1)
    }

    private var socialButtonsRow: some View {
        HStack(spacing: 20) {
            googleIconButton
            appleIconButton
        }
        .frame(maxWidth: .infinity)
    }

    private var googleIconButton: some View {
        Button {
            Task { await signInWithGoogle() }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
                    .frame(width: 56, height: 56)
                if isSigningInGoogle {
                    ProgressView()
                } else {
                    googleLogo
                }
            }
        }
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
    }

    private var appleIconButton: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
        } onCompletion: { result in
            Task { await handleAppleResult(result) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
    }

    private var googleLogo: some View {
        Text("G")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.26, green: 0.52, blue: 0.96),
                        Color(red: 0.92, green: 0.26, blue: 0.21)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Validation

    private var canSubmitLogin: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && password.count >= 6
    }

    private var canSubmitSignUp: Bool {
        canSubmitLogin && password == confirmPassword
    }

    // MARK: - Navigation

    private func goToLogin() {
        errorMessage = nil
        confirmPassword = ""
        screen = .login
    }

    private func goToSignUp() {
        errorMessage = nil
        confirmPassword = ""
        screen = .signUp
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
            if screen == .signUp {
                guard password == confirmPassword else {
                    errorMessage = "Passwords don't match."
                    isSubmittingEmail = false
                    return
                }
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
            let code = (error as? ASAuthorizationError)?.code
            if code != .canceled {
                errorMessage = friendlyError(error)
            }
        }
    }

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
