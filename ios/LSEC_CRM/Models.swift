//
//  Models.swift
//  LSEC_CRM
//
//  Codable models mirroring the JSON returned by the backend API
//  (/api/batch and the crm-* endpoints). Postgres often serialises
//  DECIMAL/NUMERIC columns as strings and INTEGER as numbers, so the
//  decoders below tolerate either representation.
//

import SwiftUI

// MARK: - Flexible decoding helpers

extension KeyedDecodingContainer {
    // `try?` flattens decodeIfPresent's Optional, so each accessor returns nil
    // for a missing key, an explicit JSON null, or a type mismatch — then we
    // fall through to the next representation.
    func flexDouble(_ key: Key) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: key), let d = Double(s) { return d }
        return nil
    }
    func flexInt(_ key: Key) -> Int? {
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        if let s = try? decodeIfPresent(String.self, forKey: key), let i = Int(s) { return i }
        return nil
    }
    func flexString(_ key: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return String(d) }
        return nil
    }
    func flexBool(_ key: Key) -> Bool? {
        if let b = try? decodeIfPresent(Bool.self, forKey: key) { return b }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            return ["true", "t", "1", "yes"].contains(s.lowercased())
        }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i != 0 }
        return nil
    }
}

// MARK: - Pipeline stages

struct Stage: Identifiable, Hashable {
    let key: String
    let label: String
    let color: Color
    var id: String { key }
}

enum Stages {
    static let all: [Stage] = [
        Stage(key: "new",       label: "New",       color: Color(hex: 0xa1a1aa)),
        Stage(key: "contacted", label: "Contacted", color: Color(hex: 0x6b7280)),
        Stage(key: "qualified", label: "Qualified", color: Color(hex: 0xf59e0b)),
        Stage(key: "proposal",  label: "Proposal",  color: Color(hex: 0x3b82f6)),
        Stage(key: "won",       label: "Won",       color: Color(hex: 0x22c55e)),
        Stage(key: "lost",      label: "Lost",      color: Color(hex: 0xef4444))
    ]
    static func meta(_ key: String?) -> Stage {
        all.first { $0.key == key } ?? all[0]
    }
}

let activityIcons: [String: String] = ["note": "📝", "call": "📞", "email": "✉️", "meeting": "🤝"]

let leadSources: [(value: String, label: String)] = [
    ("referral", "Referral"),
    ("website", "Website"),
    ("cold_call", "Cold Call"),
    ("bid_board", "Bid Board"),
    ("repeat_customer", "Repeat Customer"),
    ("other", "Other")
]

// MARK: - Lead

struct Lead: Identifiable, Equatable {
    var id: Int
    var name: String
    var company: String?
    var email: String?
    var phone: String?
    var source: String?
    var status: String
    var estimatedValue: Double?
    var customerId: Int?
    var customerName: String?
    var assignedTo: Int?
    var assignedToName: String?
    var notes: String?
    var createdBy: Int?
    var createdByName: String?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, company, email, phone, source, status, notes
        case estimatedValue = "estimated_value"
        case customerId = "customer_id"
        case customerName = "customer_name"
        case assignedTo = "assigned_to"
        case assignedToName = "assigned_to_name"
        case createdBy = "created_by"
        case createdByName = "created_by_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension Lead: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        name = c.flexString(.name) ?? ""
        company = c.flexString(.company)
        email = c.flexString(.email)
        phone = c.flexString(.phone)
        source = c.flexString(.source)
        status = c.flexString(.status) ?? "new"
        estimatedValue = c.flexDouble(.estimatedValue)
        customerId = c.flexInt(.customerId)
        customerName = c.flexString(.customerName)
        assignedTo = c.flexInt(.assignedTo)
        assignedToName = c.flexString(.assignedToName)
        notes = c.flexString(.notes)
        createdBy = c.flexInt(.createdBy)
        createdByName = c.flexString(.createdByName)
        createdAt = c.flexString(.createdAt)
        updatedAt = c.flexString(.updatedAt)
    }
}

// MARK: - Activity

struct Activity: Identifiable, Equatable {
    var id: Int
    var leadId: Int
    var activityType: String
    var note: String?
    var createdBy: Int?
    var createdByName: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, note
        case leadId = "lead_id"
        case activityType = "activity_type"
        case createdBy = "created_by"
        case createdByName = "created_by_name"
        case createdAt = "created_at"
    }
}

extension Activity: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        leadId = c.flexInt(.leadId) ?? 0
        activityType = c.flexString(.activityType) ?? "note"
        note = c.flexString(.note)
        createdBy = c.flexInt(.createdBy)
        createdByName = c.flexString(.createdByName)
        createdAt = c.flexString(.createdAt)
    }
}

// MARK: - Task

struct CRMTask: Identifiable, Equatable {
    var id: Int
    var leadId: Int?
    var title: String
    var dueDate: String?
    var status: String
    var completedAt: String?
    var createdAt: String?

    var isDone: Bool { status == "done" }

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case leadId = "lead_id"
        case dueDate = "due_date"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }
}

extension CRMTask: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        leadId = c.flexInt(.leadId)
        title = c.flexString(.title) ?? ""
        dueDate = c.flexString(.dueDate)
        status = c.flexString(.status) ?? "open"
        completedAt = c.flexString(.completedAt)
        createdAt = c.flexString(.createdAt)
    }
}

// MARK: - User

struct AppUser: Identifiable, Equatable {
    var id: Int
    var name: String
    var isActive: Bool
    var roleName: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case isActive = "is_active"
        case roleName = "role_name"
    }
}

extension AppUser: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        name = c.flexString(.name) ?? ""
        isActive = c.flexBool(.isActive) ?? true
        roleName = c.flexString(.roleName)
    }
}

// MARK: - Customer

struct Customer: Identifiable, Equatable {
    var id: Int
    var customer: String
    var address: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, customer, address
        case createdAt = "created_at"
    }
}

extension Customer: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        customer = c.flexString(.customer) ?? ""
        address = c.flexString(.address)
        createdAt = c.flexString(.createdAt)
    }
}

// MARK: - Project

struct Project: Identifiable, Equatable {
    var id: Int
    var project: String
    var customerId: Int?
    var county: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, project, county
        case customerId = "customer_id"
        case createdAt = "created_at"
    }
}

extension Project: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        project = c.flexString(.project) ?? ""
        customerId = c.flexInt(.customerId)
        county = c.flexString(.county)
        createdAt = c.flexString(.createdAt)
    }
}

// MARK: - Project Item

struct ProjectItem: Identifiable, Equatable {
    var id: Int
    var projectId: Int
    var contractQuantity: Double
    var contractRate: Double
    var installedQuantity: Double

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case contractQuantity = "contract_quantity"
        case contractRate = "contract_rate"
        case installedQuantity = "installed_quantity"
    }
}

extension ProjectItem: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        projectId = c.flexInt(.projectId) ?? 0
        contractQuantity = c.flexDouble(.contractQuantity) ?? 0
        contractRate = c.flexDouble(.contractRate) ?? 0
        installedQuantity = c.flexDouble(.installedQuantity) ?? 0
    }
}

// MARK: - Batch payload (subset used by this screen)

struct BatchData: Decodable {
    var users: [AppUser]
    var customers: [Customer]
    var projects: [Project]
    var projectItems: [ProjectItem]
    var crmLeads: [Lead]
    var crmActivities: [Activity]
    var crmTasks: [CRMTask]

    enum CodingKeys: String, CodingKey {
        case users, customers, projects
        case projectItems = "project_items"
        case crmLeads = "crm_leads"
        case crmActivities = "crm_activities"
        case crmTasks = "crm_tasks"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        users = (try? c.decode([AppUser].self, forKey: .users)) ?? []
        customers = (try? c.decode([Customer].self, forKey: .customers)) ?? []
        projects = (try? c.decode([Project].self, forKey: .projects)) ?? []
        projectItems = (try? c.decode([ProjectItem].self, forKey: .projectItems)) ?? []
        crmLeads = (try? c.decode([Lead].self, forKey: .crmLeads)) ?? []
        crmActivities = (try? c.decode([Activity].self, forKey: .crmActivities)) ?? []
        crmTasks = (try? c.decode([CRMTask].self, forKey: .crmTasks)) ?? []
    }
}

// MARK: - Customer relationship summary (derived, mirrors crm.html)

struct CustomerSummary: Identifiable {
    let customer: Customer
    let projects: [Project]
    let projectCount: Int
    let totalValue: Double
    let avgCompletion: Double
    let segment: String   // "prospects" | "active" | "completed"
    let lastActivity: String?

    var id: Int { customer.id }
}
