//
//  RootView.swift
//  LSEC_CRM
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if store.isConfigured {
                    TabView {
                        PipelineView()
                            .tabItem { Label("Pipeline", systemImage: "chart.bar.doc.horizontal") }
                        CustomerListView()
                            .tabItem { Label("Customers", systemImage: "person.2") }
                        SettingsView()
                            .tabItem { Label("Settings", systemImage: "gearshape") }
                    }
                } else {
                    SettingsView()
                }
            }

            if let banner = store.banner {
                BannerView(banner: banner)
                    .padding(.top, 4)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.banner)
        .task {
            if store.isConfigured && !store.hasLoaded { await store.reload() }
        }
    }
}
