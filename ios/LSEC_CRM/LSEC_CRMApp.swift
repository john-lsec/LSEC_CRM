//
//  LSEC_CRMApp.swift
//  LSEC_CRM
//
//  iOS port of the web "CRM - Construction Management" page (crm.html).
//  It talks to the SAME backend REST API (Netlify function over Neon Postgres)
//  that the web app uses, so it reads and writes the same database.
//

import SwiftUI

@main
struct LSEC_CRMApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
