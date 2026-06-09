import SwiftUI

struct UnlockView: View {
    let block: Block
    @EnvironmentObject var blockManager: BlockManager
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text(block.appName)
                        .font(.title.weight(.bold))
                    Text("You've been clean for")
                        .foregroundStyle(.secondary)
                    Text(Block.elapsedString(from: elapsed))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    Text("Enter the code from your friend")
                        .font(.headline)
                    TextField("4-digit code", text: $code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .onChange(of: code) { new in
                            code = String(new.prefix(4).filter(\.isNumber))
                        }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Unlock")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(code.count != 4 || isSubmitting)
                    .tint(.green)
                    .frame(width: 240)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onReceive(timer) { _ in elapsed = block.elapsed }
        .onAppear { elapsed = block.elapsed }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            try await blockManager.unlock(block: block, code: code)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

#Preview {
    UnlockView(block: Block(
        id: UUID(),
        appName: "Instagram",
        blockedDomains: ["instagram.com"],
        friendEmail: "friend@example.com",
        blockedAt: Date().addingTimeInterval(-5025)
    ))
    .environmentObject(BlockManager())
}
