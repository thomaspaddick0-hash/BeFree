import SwiftUI
import AuthenticationServices

/// Presents Sign in with Apple from a compact icon-style button (apple.logo).
@MainActor
final class AppleSignInCoordinator: NSObject, ObservableObject {
    var onConfigure: ((ASAuthorizationAppleIDRequest) -> Void)?
    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?

    func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        onConfigure?(request)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        onCompletion?(.success(authorization))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        onCompletion?(.failure(error))
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

struct AppleSignInIconButton: View {
    @ObservedObject var coordinator: AppleSignInCoordinator
    var isLoading: Bool
    var isDisabled: Bool

    var body: some View {
        Button {
            coordinator.signIn()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
                    .frame(width: 56, height: 56)
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .accessibilityLabel("Sign in with Apple")
    }
}
