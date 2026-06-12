//
//  SettingsView.swift
//  LSEC_CRM
//
//  Connection + authentication. The app talks to the same backend API as the
//  web app, so it needs the API base URL and a Bearer JWT. You can either
//  paste a token (copied from the web app's session) or sign in against your
//  auth endpoint if you have one.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @AppStorage("loginURL") private var loginURL: String = ""
    @State private var authMode: AuthMode = .token
    @State private var tokenDraft = ""
    @State private var baseDraft = ""
    @State private var email = ""
    @State private var password = ""
    @State private var working = false

    enum AuthMode: String, CaseIterable, Identifiable {
        case token = "Paste Token"
        case signIn = "Sign In"
        var id: String { rawValue }
    }

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

                Section("Authentication") {
                    Picker("Method", selection: $authMode) {
                        ForEach(AuthMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if authMode == .token {
                        LabeledField("Bearer Token (JWT)") {
                            TextField("eyJ...", text: $tokenDraft, axis: .vertical)
                                .lineLimit(1...4)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.footnote, design: .monospaced))
                        }
                    } else {
                        LabeledField("Login Endpoint URL") {
                            TextField("https://yoursite.com/.netlify/functions/login", text: $loginURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                        }
                        LabeledField("Email") {
                            TextField("you@company.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                        }
                        LabeledField("Password") {
                            SecureField("••••••••", text: $password)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await connect() }
                    } label: {
                        HStack {
                            if working { ProgressView().padding(.trailing, 6) }
                            Text(authMode == .token ? "Save & Connect" : "Sign In & Connect")
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
                            tokenDraft = ""
                            store.hasLoaded = false
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                baseDraft = store.baseURL
                tokenDraft = store.token
            }
        }
    }

    private func connect() async {
        working = true
        defer { working = false }

        let base = baseDraft.trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { store.show("Enter the API Base URL", isError: true); return }
        store.baseURL = base

        if authMode == .token {
            let t = tokenDraft.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { store.show("Enter a token", isError: true); return }
            store.token = t
        } else {
            do {
                let t = try await signIn()
                store.token = t
                tokenDraft = t
            } catch {
                store.show(error)
                return
            }
        }

        store.hasLoaded = false
        await store.reload()
        if store.hasLoaded { store.show("Connected") }
    }

    private func signIn() async throws -> String {
        let urlStr = loginURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: urlStr) else { throw APIError(message: "Enter a valid login URL") }
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
