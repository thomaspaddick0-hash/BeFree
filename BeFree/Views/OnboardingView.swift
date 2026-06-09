import SwiftUI
import FamilyControls

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var isRequesting = false
    @State private var authError: String?

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
                if let error = authError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: requestAuthorization) {
                    Group {
                        if isRequesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Get Started")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRequesting)
                .padding(.horizontal)

                Text("BeFree needs Screen Time permission to block apps.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 48)
        }
    }

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

    private func requestAuthorization() {
        isRequesting = true
        authError = nil
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                onComplete()
            } catch {
                authError = "Permission is required to block apps. Please allow Screen Time access."
            }
            isRequesting = false
        }
    }
}

#Preview {
    OnboardingView { }
}
