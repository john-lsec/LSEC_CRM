//
//  PipelineView.swift
//  LSEC_CRM
//
//  Sales pipeline: KPI summary + the 6-stage board (mirrors renderPipeline /
//  renderLeadKpis / leadCardHtml). Stage changes are done with a menu on each
//  card's stage chip, the touch equivalent of the web drag-and-drop.
//

import SwiftUI

struct PipelineView: View {
    @EnvironmentObject var store: AppStore

    @State private var search = ""
    @State private var ownerFilter: Int? = nil
    @State private var showAddLead = false
    @State private var detailLeadId: Int? = nil

    private var filteredLeads: [Lead] {
        var list = store.leads
        let s = search.lowercased().trimmingCharacters(in: .whitespaces)
        if !s.isEmpty {
            list = list.filter {
                ($0.name.lowercased().contains(s)) ||
                ($0.company?.lowercased().contains(s) ?? false) ||
                ($0.email?.lowercased().contains(s) ?? false) ||
                ($0.phone?.lowercased().contains(s) ?? false)
            }
        }
        if let owner = ownerFilter {
            list = list.filter { $0.assignedTo == owner }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    kpiGrid
                    toolbar
                    board
                }
                .padding(.vertical)
            }
            .background(Theme.surfaceHover.ignoresSafeArea())
            .navigationTitle("Sales Pipeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.canEdit {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showAddLead = true } label: { Label("Add Lead", systemImage: "plus") }
                    }
                }
            }
            .refreshable { await store.reload() }
        }
        .sheet(isPresented: $showAddLead) {
            LeadEditView(editing: nil)
        }
        .sheet(item: Binding(
            get: { detailLeadId.map { IDWrap(id: $0) } },
            set: { detailLeadId = $0?.id })
        ) { wrap in
            LeadDetailView(leadId: wrap.id)
        }
    }

    // MARK: KPI grid

    private var kpiGrid: some View {
        let k = store.leadKPIs
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            KPICard(label: "Open Leads", value: "\(k.openCount)", sub: "\(k.totalCount) total")
            KPICard(label: "Open Pipeline Value", value: Fmt.currency(k.openValue),
                    sub: "estimated, excl. won/lost", accent: true)
            KPICard(label: "Won", value: "\(k.wonCount)", sub: "\(Fmt.currency(k.wonValue)) closed")
            KPICard(label: "Open Follow-ups", value: "\(k.openTasks)", sub: "\(k.overdueTasks) overdue")
        }
        .padding(.horizontal)
    }

    // MARK: Toolbar (search + owner)

    private var toolbar: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(Theme.muted)
                TextField("Search leads by name, company, or contact...", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Menu {
                Button("All Owners") { ownerFilter = nil }
                ForEach(store.ownerIds, id: \.self) { id in
                    Button(store.userName(id).isEmpty ? "User \(id)" : store.userName(id)) {
                        ownerFilter = id
                    }
                }
            } label: {
                HStack {
                    Text(ownerFilter == nil ? "All Owners" : store.userName(ownerFilter!))
                        .foregroundColor(Theme.dark)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption).foregroundColor(Theme.muted)
                }
                .padding(10)
                .background(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
    }

    // MARK: Board

    private var board: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Stages.all) { stage in
                    column(for: stage)
                }
            }
            .padding(.horizontal)
        }
    }

    private func column(for stage: Stage) -> some View {
        let colLeads = filteredLeads.filter { $0.status == stage.key }
        let colValue = colLeads.reduce(0.0) { $0 + Fmt.toNumber($1.estimatedValue) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(stage.color).frame(width: 9, height: 9)
                    Text(stage.label).font(.subheadline.weight(.bold)).foregroundColor(Theme.dark)
                }
                Spacer()
                Text("\(colLeads.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 1)
                    .background(Theme.surface)
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 4)
            .overlay(Rectangle().fill(Theme.border).frame(height: 2), alignment: .bottom)

            Text(Fmt.currency(colValue)).font(.caption).foregroundColor(Theme.muted)

            if colLeads.isEmpty {
                Text("No leads")
                    .font(.caption)
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                ForEach(colLeads) { lead in
                    LeadCardView(lead: lead) { detailLeadId = lead.id }
                }
            }
        }
        .padding(10)
        .frame(width: 240, alignment: .leading)
        .background(Theme.surfaceHover)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Lead card

struct LeadCardView: View {
    @EnvironmentObject var store: AppStore
    let lead: Lead
    let onTap: () -> Void

    private var stage: Stage { Stages.meta(lead.status) }
    private var ownerName: String { lead.assignedToName ?? store.userName(lead.assignedTo) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lead.name).font(.subheadline.weight(.semibold)).foregroundColor(Theme.dark)
            if let company = lead.company, !company.isEmpty {
                Text(company).font(.caption).foregroundColor(Theme.muted)
            }
            HStack {
                stageChip
                Spacer()
                Text(lead.estimatedValue != nil ? Fmt.currency(lead.estimatedValue) : "—")
                    .font(.caption.weight(.bold)).foregroundColor(Theme.dark)
            }
            HStack {
                HStack(spacing: 5) {
                    if store.activityCount(for: lead.id) > 0 {
                        MiniChip(text: "💬 \(store.activityCount(for: lead.id))")
                    }
                    if store.openTaskCount(for: lead.id) > 0 {
                        MiniChip(text: "⏰ \(store.openTaskCount(for: lead.id))")
                    }
                }
                Spacer()
                if !ownerName.isEmpty {
                    MiniChip(text: Fmt.initials(ownerName))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(
            HStack(spacing: 0) {
                Rectangle().fill(stage.color).frame(width: 3)
                Spacer()
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var stageChip: some View {
        Menu {
            if store.canEdit {
                ForEach(Stages.all) { s in
                    Button {
                        Task { await store.changeLeadStage(lead.id, to: s.key) }
                    } label: {
                        if s.key == lead.status { Label(s.label, systemImage: "checkmark") }
                        else { Text(s.label) }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(stage.label)
                if store.canEdit { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(stage.color)
            .clipShape(Capsule())
        }
        .disabled(!store.canEdit)
    }
}

/// Helper to drive an item-based sheet from an Int id.
struct IDWrap: Identifiable { let id: Int }
