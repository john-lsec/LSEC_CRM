//
//  CustomerDetailView.swift
//  LSEC_CRM
//
//  Customer relationship detail (mirrors openCustomerDetail): header summary
//  plus the list of projects with contract value and completion.
//

import SwiftUI

struct CustomerDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let customerId: Int

    private var customer: Customer? { store.customers.first { $0.id == customerId } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let customer {
                    let summary = store.summary(for: customer)
                    VStack(alignment: .leading, spacing: 18) {
                        GradientHeader {
                            Text("🏢 \(customer.customer)").font(.headline)
                            Text(customer.address?.isEmpty == false ? customer.address! : "No address on file")
                                .font(.caption).opacity(0.9)
                            HStack(spacing: 6) {
                                Text("\(summary.projectCount) project\(summary.projectCount == 1 ? "" : "s")")
                                Text("· \(Fmt.currency(summary.totalValue)) total value")
                                segmentBadge(summary.segment)
                            }
                            .font(.caption).opacity(0.95).padding(.top, 4)
                        }

                        if summary.projects.isEmpty {
                            EmptyState(icon: "📋", message: "No projects yet for this prospect.")
                        } else {
                            ForEach(summary.projects.sorted {
                                store.contractValue(projectId: $0.id) > store.contractValue(projectId: $1.id)
                            }) { p in
                                projectRow(p)
                            }
                        }
                    }
                    .padding()
                } else {
                    EmptyState(icon: "🏢", message: "Customer not available.").padding(.top, 60)
                }
            }
            .background(Theme.surfaceHover.ignoresSafeArea())
            .navigationTitle(customer.map { "\($0.customer)" } ?? "Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func projectRow(_ p: Project) -> some View {
        let completion = store.completion(projectId: p.id)
        let value = store.contractValue(projectId: p.id)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🏗️ \(p.project)").font(.subheadline.weight(.semibold)).foregroundColor(Theme.dark)
                Text("\(p.county.map { "\($0) · " } ?? "")\(String(format: "%.0f", completion))% complete")
                    .font(.caption2).foregroundColor(Theme.muted)
            }
            Spacer()
            Text(Fmt.currency(value)).font(.subheadline.weight(.bold)).foregroundColor(Theme.dark)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }
}
