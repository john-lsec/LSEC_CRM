//
//  SettingsView.swift
//  LSEC_CRM
//
//  Connection + authentication. The app talks to the same backend API as the
//  web app, so it needs the API base URL and credentials. You sign in with the
//  same email/password and login endpoint the web app uses.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var baseDraft = ""
    @State private var email = ""
    @State private var password = ""
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField("API Base URL") {
                        TextField("https://yoursite.com/api", text: $baseDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Points at the same REST API the web app uses (api.js). Usually your site origin followed by /api.")
                }

                Section {
                    LabeledField("Email") {
                        TextField("you@company.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                    }
                    LabeledField("Password") {
                        SecureField("••••••••", text: $password)
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Signs in against \(loginEndpoint(from: baseDraft)) with your email and password — the same endpoint the web app uses.")
                }

                Section {
                    Button {
                        Task { await connect() }
                    } label: {
                        HStack {
                            if working { ProgressView().padding(.trailing, 6) }
                            Text("Sign In & Connect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.dark)
                    .disabled(working)
                }

                if store.isConfigured {
                    Section("Status") {
                        HStack {
                            Text("Signed in as")
                            Spacer()
                            Text(store.currentUserName).foregroundColor(Theme.muted)
                        }
                        Button("Reload Data") { Task { await store.reload() } }
                        Button("Sign Out", role: .destructive) {
                            store.token = ""
                            store.hasLoaded = false
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                baseDraft = store.baseURL
            }
        }
    }

    private func connect() async {
        working = true
        defer { working = false }

        let base = baseDraft.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { store.show("Enter the API Base URL", isError: true); return }
        store.baseURL = base

        do {
            store.token = try await signIn()
        } catch {
            store.show(error)
            return
        }

        store.hasLoaded = false
        await store.reload()
        if store.hasLoaded { store.show("Connected") }
    }

    /// Derives the login endpoint from the API Base URL the same way the web
    /// app does: the web app's API_BASE is the site origin and it POSTs to
    /// `/auth/login` (a Netlify redirect to the `auth` function). The iOS base
    /// URL is the origin followed by `/api`, so strip that suffix to recover
    /// the origin and append `/auth/login`.
    private func loginEndpoint(from base: String) -> String {
        var origin = base.trimmingCharacters(in: .whitespaces)
        while origin.hasSuffix("/") { origin.removeLast() }
        for suffix in ["/api", "/.netlify/functions"] {
            if origin.hasSuffix(suffix) {
                origin.removeLast(suffix.count)
                break
            }
        }
        while origin.hasSuffix("/") { origin.removeLast() }
        return origin + "/auth/login"
    }

    private func signIn() async throws -> String {
        let urlStr = loginEndpoint(from: store.baseURL)
        guard let url = URL(string: urlStr) else { throw APIError(message: "Enter a valid API Base URL") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String { throw APIError(message: msg) }
            throw APIError(message: "Sign in failed")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError(message: "Unexpected sign-in response")
        }
        for key in ["token", "accessToken", "jwt", "access_token"] {
            if let t = obj[key] as? String { return t }
        }
        // Some APIs nest under "data".
        if let inner = obj["data"] as? [String: Any] {
            for key in ["token", "accessToken", "jwt"] {
                if let t = inner[key] as? String { return t }
            }
        }
        throw APIError(message: "No token found in sign-in response")
    }
}
