//
//  CRMRepository.swift
//  LSEC_CRM
//
//  Typed wrappers around the CRM REST endpoints exposed by api.js:
//    GET    /batch                          -> full data snapshot
//    POST   /crm-leads                      -> create lead
//    PUT    /crm-leads/:id                  -> update lead (incl. stage)
//    DELETE /crm-leads/:id                  -> delete lead (+ cascade)
//    POST   /crm-leads/:id/activities       -> log activity
//    DELETE /crm-activities/:id             -> delete activity
//    POST   /crm-leads/:id/tasks            -> add follow-up task
//    PUT    /crm-tasks/:id                  -> toggle/update task
//    DELETE /crm-tasks/:id                  -> delete task
//

import Foundation

struct CRMRepository {
    let client: APIClient

    func loadBatch() async throws -> BatchData {
        try await client.get("/batch")
    }

    // MARK: Leads

    @discardableResult
    func createLead(_ data: LeadInput) async throws -> Lead {
        try await client.post("/crm-leads", body: data.body)
    }

    @discardableResult
    func updateLead(_ id: Int, _ data: [String: Any?]) async throws -> Lead {
        try await client.put("/crm-leads/\(id)", body: data)
    }

    func deleteLead(_ id: Int) async throws {
        try await client.delete("/crm-leads/\(id)")
    }

    // MARK: Activities

    @discardableResult
    func createActivity(leadId: Int, type: String, note: String) async throws -> Activity {
        try await client.post("/crm-leads/\(leadId)/activities",
                              body: ["activity_type": type, "note": note])
    }

    func deleteActivity(_ id: Int) async throws {
        try await client.delete("/crm-activities/\(id)")
    }

    // MARK: Tasks

    @discardableResult
    func createTask(leadId: Int, title: String, dueDate: String?) async throws -> CRMTask {
        try await client.post("/crm-leads/\(leadId)/tasks",
                              body: ["title": title, "due_date": dueDate])
    }

    @discardableResult
    func updateTask(_ id: Int, status: String) async throws -> CRMTask {
        try await client.put("/crm-tasks/\(id)", body: ["status": status])
    }

    func deleteTask(_ id: Int) async throws {
        try await client.delete("/crm-tasks/\(id)")
    }
}

/// Payload for create/edit lead, mirroring the web "Add/Edit Lead" form.
struct LeadInput {
    var name: String
    var company: String?
    var email: String?
    var phone: String?
    var status: String
    var estimatedValue: Double?
    var source: String?
    var assignedTo: Int?
    var customerId: Int?
    var notes: String?

    var body: [String: Any?] {
        [
            "name": name,
            "company": company,
            "email": email,
            "phone": phone,
            "status": status,
            "estimated_value": estimatedValue,
            "source": source,
            "assigned_to": assignedTo,
            "customer_id": customerId,
            "notes": notes
        ]
    }
}
