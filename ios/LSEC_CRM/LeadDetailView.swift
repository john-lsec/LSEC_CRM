//
//  LeadDetailView.swift
//  LSEC_CRM
//
//  Lead detail: header + activity log + follow-up tasks (mirrors
//  openLeadDetail / renderLeadActivities / renderLeadTasks).
//

import SwiftUI

struct LeadDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let leadId: Int

    @State private var activityType = "note"
    @State private var activityNote = ""
    @State private var taskTitle = ""
    @State private var taskDue = Date()
    @State private var useDue = false
    @State private var showEdit = false
    @State private var confirmDeleteLead = false

    private var lead: Lead? { store.leads.first { $0.id == leadId } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let lead {
                    VStack(alignment: .leading, spacing: 22) {
                        header(lead)
                        activitySection
                        taskSection
                        if store.canEdit { footer }
                    }
                    .padding()
                } else {
                    EmptyState(icon: "🗑️", message: "This lead is no longer available.")
                        .padding(.top, 60)
                }
            }
            .background(Theme.surfaceHover.ignoresSafeArea())
            .navigationTitle(lead?.name ?? "Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if store.canEdit, lead != nil {
                    ToolbarItem(placement: .primaryAction) { Button("Edit") { showEdit = true } }
                }
            }
        }
        .sheet(isPresented: $showEdit) { if let lead { LeadEditView(editing: lead) } }
        .confirmationDialog("Delete this lead and all its activities and tasks?",
                            isPresented: $confirmDeleteLead, titleVisibility: .visible) {
            Button("Delete Lead", role: .destructive) {
                Task { if await store.deleteLead(leadId) { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header

    private func header(_ lead: Lead) -> some View {
        let stage = Stages.meta(lead.status)
        let owner = lead.assignedToName ?? store.userName(lead.assignedTo)
        let customer = store.customers.first { $0.id == lead.customerId }
        return GradientHeader {
            Text(lead.name + (lead.company.map { " · \($0)" } ?? ""))
                .font(.headline)
            HStack(spacing: 6) {
                Badge(text: stage.label, background: stage.color)
                if let v = lead.estimatedValue { Text("· \(Fmt.currency(v))").font(.caption) }
                if !owner.isEmpty { Text("· Owner: \(owner)").font(.caption) }
            }
            .opacity(0.95)
            if (lead.email?.isEmpty == false) || (lead.phone?.isEmpty == false) {
                HStack(spacing: 12) {
                    if let e = lead.email, !e.isEmpty { Text("✉️ \(e)").font(.caption) }
                    if let p = lead.phone, !p.isEmpty { Text("📞 \(p)").font(.caption) }
                }
                .opacity(0.9)
            }
            if let customer { Text("🏢 Linked customer: \(customer.customer)").font(.caption).opacity(0.9) }
            if let n = lead.notes, !n.isEmpty {
                Text(n).font(.caption).opacity(0.9).padding(.top, 4)
            }
        }
    }

    // MARK: Activities

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Log").font(.headline)
            if store.canEdit {
                VStack(spacing: 8) {
                    Picker("Type", selection: $activityType) {
                        ForEach(["note", "call", "email", "meeting"], id: \.self) { t in
                            Text("\(activityIcons[t] ?? "") \(t.capitalized)").tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Log a call, email, meeting or note...", text: $activityNote, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(8)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        let note = activityNote.trimmingCharacters(in: .whitespaces)
                        guard !note.isEmpty else { store.show("Enter a note to log", isError: true); return }
                        activityNote = ""
                        Task { await store.logActivity(leadId: leadId, type: activityType, note: note) }
                    } label: {
                        Text("Log").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.dark)
                }
            }

            let acts = store.leadActivities(leadId)
            if acts.isEmpty {
                Text("No activity logged yet.").font(.subheadline).foregroundColor(Theme.muted)
                    .padding(.vertical, 8)
            } else {
                ForEach(acts) { a in activityRow(a) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func activityRow(_ a: Activity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(activityIcons[a.activityType] ?? "📝") \(a.activityType.capitalized)")
                    .font(.subheadline.weight(.semibold)).foregroundColor(Theme.dark)
                Spacer()
                Text("\(a.createdByName ?? store.userName(a.createdBy)) · \(Fmt.dateTime(a.createdAt))")
                    .font(.caption2).foregroundColor(Theme.muted)
                if store.canEdit {
                    Button("delete") { Task { await store.deleteActivity(a.id) } }
                        .font(.caption2).foregroundColor(Theme.danger)
                }
            }
            if let note = a.note, !note.isEmpty {
                Text(note).font(.subheadline).foregroundColor(Theme.dark)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: Tasks

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Follow-up Tasks").font(.headline)
            if store.canEdit {
                VStack(spacing: 8) {
                    TextField("Follow-up task...", text: $taskTitle)
                        .padding(8)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Toggle("Due date", isOn: $useDue).labelsHidden()
                        if useDue {
                            DatePicker("", selection: $taskDue, displayedComponents: .date)
                                .labelsHidden()
                        } else {
                            Text("No due date").font(.caption).foregroundColor(Theme.muted)
                        }
                        Spacer()
                        Button {
                            let title = taskTitle.trimmingCharacters(in: .whitespaces)
                            guard !title.isEmpty else { store.show("Enter a task title", isError: true); return }
                            let due = useDue ? Self.isoDay.string(from: taskDue) : nil
                            taskTitle = ""; useDue = false
                            Task { await store.addTask(leadId: leadId, title: title, dueDate: due) }
                        } label: { Text("Add") }
                            .buttonStyle(.borderedProminent).tint(Theme.dark)
                    }
                }
            }

            let tasks = store.leadTasks(leadId)
            if tasks.isEmpty {
                Text("No follow-up tasks.").font(.subheadline).foregroundColor(Theme.muted)
                    .padding(.vertical, 8)
            } else {
                ForEach(tasks) { t in taskRow(t) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func taskRow(_ t: CRMTask) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        let overdue = !t.isDone && (Fmt.parse(t.dueDate).map { $0 < today } ?? false)
        return HStack(alignment: .top, spacing: 10) {
            Button {
                Task { await store.toggleTask(t.id, done: !t.isDone) }
            } label: {
                Image(systemName: t.isDone ? "checkmark.square.fill" : "square")
                    .foregroundColor(t.isDone ? Theme.dark : Theme.muted)
            }
            .disabled(!store.canEdit)
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(t.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(t.isDone)
                    .foregroundColor(t.isDone ? Theme.muted : Theme.dark)
                HStack(spacing: 6) {
                    Text(t.dueDate != nil ? (overdue ? "⚠️ Due " : "Due ") + Fmt.date(t.dueDate) : "No due date")
                        .font(.caption2).foregroundColor(Theme.muted)
                    if overdue { Badge(text: "Overdue", background: Theme.warning) }
                }
            }
            Spacer()
            if store.canEdit {
                Button("delete") { Task { await store.deleteTask(t.id) } }
                    .font(.caption2).foregroundColor(Theme.danger)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: Footer

    private var footer: some View {
        Button(role: .destructive) { confirmDeleteLead = true } label: {
            Text("Delete Lead").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).tint(Theme.danger)
    }

    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
