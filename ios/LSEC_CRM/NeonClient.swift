//
//  NeonClient.swift
//  LSEC_CRM
//
//  Thin REST client for the LSEC CRM backend. The backend is a Netlify
//  function (api.js) running on top of Neon Postgres (DATABASE_URL); this
//  client calls the very same endpoints the web app uses, so it reads and
//  writes the same database. Auth is a Bearer JWT (same token format the
//  web app stores after login).
//

import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class APIClient {
    /// Base URL pointing at the API root, e.g. "https://yoursite.com/api"
    var baseURL: String
    /// Bearer JWT used by the backend's verifyToken().
    var token: String

    init(baseURL: String, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    private func makeURL(_ path: String) throws -> URL {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") { base.removeLast() }
        let p = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: base + p) else {
            throw APIError(message: "Invalid URL: \(base + p)")
        }
        return url
    }

    /// Performs a request and returns raw data. Throws APIError on non-2xx.
    @discardableResult
    func send(method: String, path: String, body: [String: Any?]? = nil) async throws -> Data {
        var req = URLRequest(url: try makeURL(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            // Convert [String: Any?] (with nils) into a JSON object preserving nulls.
            var json: [String: Any] = [:]
            for (k, v) in body { json[k] = v ?? NSNull() }
            req.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError(message: "Network error: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Backend returns { "error": "..." } on failure.
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw APIError(message: msg)
            }
            throw APIError(message: "Request failed (HTTP \(http.statusCode))")
        }
        return data
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await send(method: "GET", path: path)
        return try decode(T.self, from: data)
    }

    @discardableResult
    func post<T: Decodable>(_ path: String, body: [String: Any?]) async throws -> T {
        let data = try await send(method: "POST", path: path, body: body)
        return try decode(T.self, from: data)
    }

    @discardableResult
    func put<T: Decodable>(_ path: String, body: [String: Any?]) async throws -> T {
        let data = try await send(method: "PUT", path: path, body: body)
        return try decode(T.self, from: data)
    }

    func delete(_ path: String) async throws {
        try await send(method: "DELETE", path: path)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError(message: "Failed to parse server response.")
        }
    }
}

/// Best-effort decode of a (possibly unsigned) JWT payload so the app can show
/// who is signed in. The backend only base64-decodes the payload too.
enum JWT {
    static func payload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    static func userId(_ token: String) -> Int? {
        guard let p = payload(token) else { return nil }
        if let i = p["userId"] as? Int { return i }
        if let s = p["userId"] as? String { return Int(s) }
        if let i = p["id"] as? Int { return i }
        return nil
    }

    static func name(_ token: String) -> String? {
        payload(token)?["name"] as? String
    }
}
