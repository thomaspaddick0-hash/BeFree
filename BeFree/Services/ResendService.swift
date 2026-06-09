import Foundation

final class ResendService {
    static let shared = ResendService()

    // TODO: Replace with your Resend API key and verified sending domain
    private let apiKey = "YOUR_RESEND_API_KEY"
    private let fromAddress = "BeFree <noreply@yourdomain.com>"

    func sendCode(_ code: String, appName: String, userName: String, toEmail: String) async throws {
        var req = URLRequest(url: URL(string: "https://api.resend.com/emails")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "from": fromAddress,
            "to": [toEmail],
            "subject": "Your friend needs your help — BeFree code inside",
            "html": emailHTML(code: code, appName: appName, userName: userName)
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BeFreeError.serverError
        }
    }

    private func emailHTML(code: String, appName: String, userName: String) -> String {
        """
        <div style="font-family:sans-serif;max-width:480px;margin:40px auto;padding:32px;border-radius:12px;background:#f9f9f9">
          <h2 style="margin-top:0">Your friend is counting on you 🔒</h2>
          <p><strong>\(userName)</strong> has blocked themselves from <strong>\(appName)</strong> using BeFree.</p>
          <p>Their unlock code is:</p>
          <div style="font-size:48px;font-weight:bold;letter-spacing:12px;text-align:center;padding:24px;background:#fff;border-radius:8px;margin:16px 0">\(code)</div>
          <p style="color:#666;font-size:14px">Only share this code when you think they've genuinely earned it. That's why they trusted you with it.</p>
          <p style="color:#999;font-size:12px">Sent by BeFree — a personal accountability app.</p>
        </div>
        """
    }
}
