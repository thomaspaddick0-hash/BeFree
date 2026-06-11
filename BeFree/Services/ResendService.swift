import Foundation

final class ResendService {
    static let shared = ResendService()

    private let apiKey = Secrets.resendAPIKey
    private let fromAddress = "BeFree <onboarding@resend.dev>"

    func sendCode(_ code: String, appName: String, toEmail: String, userName: String) async throws {
        var req = URLRequest(url: URL(string: "https://api.resend.com/emails")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        let displayName = trimmedName.isEmpty ? "Someone" : trimmedName

        let body: [String: Any] = [
            "from": fromAddress,
            "to": [toEmail],
            "subject": "\(displayName) is counting on you — BeFree unlock code",
            "html": emailHTML(code: code, appName: appName, userName: displayName)
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw ResendError.failed(body)
        }
    }

    private func emailHTML(code: String, appName: String, userName: String) -> String {
        """
        <div style="font-family:sans-serif;max-width:480px;margin:40px auto;padding:32px;border-radius:12px;background:#f9f9f9">
          <h2 style="margin-top:0">\(userName) is counting on you 🔒</h2>
          <p><strong>\(userName)</strong> has blocked themselves from <strong>\(appName)</strong> using BeFree and trusted you with their unlock code.</p>
          <p>Their unlock code is:</p>
          <div style="font-size:48px;font-weight:bold;letter-spacing:12px;text-align:center;padding:24px;background:#fff;border-radius:8px;margin:16px 0">\(code)</div>
          <p style="color:#666;font-size:14px">Only share this code when you think they've genuinely earned it. That's why they trusted you with it.</p>
          <p style="color:#999;font-size:12px">Sent by BeFree — a personal accountability app.</p>
        </div>
        """
    }
}
