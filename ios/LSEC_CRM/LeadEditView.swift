//
//  LeadEditView.swift
//  LSEC_CRM
//
//  Add / Edit Lead form (mirrors the #lead-modal form and saveLead()).
//

import SwiftUI

struct LeadEditView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let editing: Lead?

    @State private var name = ""
    @State private var company = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var status = "new"
    @State private var valueText = ""
    @State private var source = ""
    @State private var assignedTo: Int? = nil
    @State private var customerId: Int? = nil
    @State private var notes = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField("Lead / Contact Name *") {
                        TextField("Required", text: $name)
                    }
                    LabeledField("Company") { TextField("", text: $company) }
                    LabeledField("Email") {
                        TextField("", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledField("Phone") {
                        TextField("", text: $phone).keyboardType(.phonePad)
                    }
                }

                Section {
                    Picker("Stage", selection: $status) {
                        ForEach(Stages.all) { Text($0.label).tag($0.key) }
                    }
                    LabeledField("Estimated Value ($)") {
                        TextField("", text: $valueText).keyboardType(.decimalPad)
                    }
                    Picker("Source", selection: $source) {
                        Text("—").tag("")
                        ForEach(leadSources, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    Picker("Assigned To", selection: $assignedTo) {
                        Text("— Unassigned —").tag(Int?.none)
                        ForEach(store.users.filter { $0.isActive }) { u in
                            Text(u.name).tag(Int?.some(u.id))
                        }
                    }
                    Picker("Linked Customer", selection: $customerId) {
                        Text("— None —").tag(Int?.none)
                        ForEach(store.customers) { c in
                            Text(c.customer).tag(Int?.some(c.id))
                        }
                    }
                }

                Section("Notes") {
                    TextField("", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(editing == nil ? "Add Lead" : "Edit Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(saving)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let l = editing else {
            assignedTo = store.currentUserId
            return
        }
        name = l.name
        company = l.company ?? ""
        email = l.email ?? ""
        phone = l.phone ?? ""
        status = l.status
        valueText = l.estimatedValue.map { String(format: "%g", $0) } ?? ""
        source = l.source ?? ""
        assignedTo = l.assignedTo
        customerId = l.customerId
        notes = l.notes ?? ""
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { store.show("Lead name is required", isError: true); return }
        saving = true; defer { saving = false }
        func clean(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespaces); return t.isEmpty ? nil : t
        }
        let input = LeadInput(
            name: trimmed,
            company: clean(company),
            email: clean(email),
            phone: clean(phone),
            status: status,
            estimatedValue: valueText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Double(valueText),
            source: source.isEmpty ? nil : source,
            assignedTo: assignedTo,
            customerId: customerId,
            notes: clean(notes)
        )
        if await store.saveLead(input, editingId: editing?.id) { dismiss() }
    }
}

struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(Theme.muted)
            content
        }
    }
}
