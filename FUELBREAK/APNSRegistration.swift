//
//  APNSRegistration.swift
//  FUELBREAK
//
//  Created by alew on 4/30/26.
//


import Foundation

/// Single source of truth for sending an APNs token + userId to Lambda.
/// Called from native Swift only — never relies on the WebView JS fetch.
enum APNSRegistration {

    private static let endpoint = "https://y25m8puewi.execute-api.us-west-1.amazonaws.com/prod/fuelbreak-notify"

    /// POST { action, user_id, device_token } to Lambda.
    /// Safe to call from any thread.
    static func send(token: String, userId: String) {
        guard !token.isEmpty, !userId.isEmpty else {
            print("⚠️ [APNSRegistration] Skipping – token or userId is empty (token: \(token.isEmpty), userId: \(userId.isEmpty))")
            return
        }

        guard let url = URL(string: endpoint) else {
            print("❌ [APNSRegistration] Invalid endpoint URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "action":       "register",
            "user_id":      userId,
            "device_token": token
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ [APNSRegistration] JSON serialisation failed: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [APNSRegistration] Network error: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("📱 [APNSRegistration] HTTP \(http.statusCode) for userId: \(userId)")
            }
            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("📱 [APNSRegistration] Response: \(body)")
            }
        }.resume()
    }
}