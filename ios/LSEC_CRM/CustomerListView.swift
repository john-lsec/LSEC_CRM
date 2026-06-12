//
//  CustomerListView.swift
//  LSEC_CRM
//
//  Customer Relationships list (mirrors renderCustomers): search, segment
//  filter, sort, and the relationship cards derived from projects/items.
//

import SwiftUI

enum CRMSort: String, CaseIterable, Identifiable {
    case value, projects, name, recent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .value: return "Sort: Pipeline Value"
        case .projects: return "Sort: Most Projects"
        case .name: return "Sort: Name (A–Z)"
        case .recent: return "Sort: Most Recent"
        }
    }
}

enum CRMSegment: String, CaseIterable, Identifiable {
    case all = ""
    case prospects, active, completed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All Segments"
        case .prospects: return "Prospects (no projects)"
        case .active: return "Active (in progress)"
        case .completed: return "Completed only"
        }
    }
}

struct CustomerListView: View {
    @EnvironmentObject var store: AppStore

    @State private var search = ""
    @State private var segment: CRMSegment = .all
    @State private var sort: CRMSort = .value
    @State private var detailCustomerId: Int? = nil

    private var list: [CustomerSummary] {
        var l = store.allSummaries
        let s = search.lowercased().trimmingCharacters(in: .whitespaces)
        if !s.isEmpty {
            l = l.filter {
                $0.customer.customer.lowercased().contains(s) ||
                ($0.customer.address?.lowercased().contains(s) ?? false)
            }
        }
        if segment != .all { l = l.filter { $0.segment == segment.rawValue } }
        l.sort { a, b in
            switch sort {
            case .projects: return a.projectCount > b.projectCount
            case .name: return a.customer.customer.localizedCaseInsensitiveCompare(b.customer.customer) == .orderedAscending
            case .recent:
                return (Fmt.parse(a.lastActivity) ?? .distantPast) > (Fmt.parse(b.lastActivity) ?? .distantPast)
            case .value: return a.totalValue > b.totalValue
            }
        }
        return l
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    toolbar
                    if list.isEmpty {
                        EmptyState(icon: "🤝",
                                   message: store.customers.isEmpty
                                   ? "No customers yet. Add customers from the Customers page to start managing relationships."
                                   : "No customers match the current filters.")
                    } else {
                        ForEach(list) { s in
                            CustomerCardView(summary: s) { detailCustomerId = s.customer.id }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.surfaceHover.ignoresSafeArea())
            .navigationTitle("Customer Relationships")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.reload() }
        }
        .sheet(item: Binding(
            get: { detailCustomerId.map { IDWrap(id: $0) } },
            set: { detailCustomerId = $0?.id })
        ) { wrap in
            CustomerDetailView(customerId: wrap.id)
        }
    }

    private var toolbar: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(Theme.muted)
                TextField("Search customers or addresses...", text: $search)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 10) {
                Menu {
                    ForEach(CRMSegment.allCases) { seg in
                        Button(seg.label) { segment = seg }
                    }
                } label: { filterLabel(segment.label) }

                Menu {
                    ForEach(CRMSort.allCases) { s in
                        Button(s.label) { sort = s }
                    }
                } label: { filterLabel(sort.label) }
            }
        }
    }

    private func filterLabel(_ text: String) -> some View {
        HStack {
            Text(text).foregroundColor(Theme.dark).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down").font(.caption).foregroundColor(Theme.muted)
        }
        .padding(10)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CustomerCardView: View {
    let summary: CustomerSummary
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.customer.customer)
                        .font(.headline).foregroundColor(Theme.dark)
                    Text(summary.customer.address?.isEmpty == false ? summary.customer.address! : "No address on file")
                        .font(.caption).foregroundColor(Theme.muted)
                }
                Spacer()
                segmentBadge(summary.segment)
            }

            HStack {
                stat("Projects", "\(summary.projectCount)")
                Spacer()
                stat("Pipeline Value", Fmt.currency(summary.totalValue))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("AVG. COMPLETION").font(.caption2).tracking(0.4).foregroundColor(Theme.muted)
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.border)
                            Capsule().fill(Theme.dark)
                                .frame(width: geo.size.width * summary.avgCompletion / 100)
                        }
                    }
                    .frame(height: 8)
                    Text(String(format: "%.0f%%", summary.avgCompletion))
                        .font(.caption.weight(.semibold)).foregroundColor(Theme.dark)
                        .frame(width: 44, alignment: .trailing)
                }
            }

            Text("Last activity: \(summary.lastActivity != nil ? Fmt.date(summary.lastActivity) : "N/A")")
                .font(.caption2).foregroundColor(Theme.muted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.caption2).tracking(0.4).foregroundColor(Theme.muted)
            Text(value).font(.subheadline.weight(.semibold)).foregroundColor(Theme.dark)
        }
    }
}
