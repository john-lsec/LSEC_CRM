//
//  AppStore.swift
//  LSEC_CRM
//
//  Central observable state. Loads the data snapshot from /batch and performs
//  the same create/update/delete operations the web crm.html performs, with
//  optimistic updates for stage changes (matching changeLeadStage()).
//

import SwiftUI

private let ROLE_HIERARCHY: [String: Int] = [
    "Admin": 9, "Accounts Payable": 8, "Accounts Receivable": 8, "Human Resources": 8,
    "Estimator": 7, "Project Manager": 7, "Superintendent": 6, "Crew Leader": 5, "Crew Member": 1
]

struct Banner: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

@MainActor
final class AppStore: ObservableObject {
    // Configuration (persisted)
    @AppStorage("apiBaseURL") var baseURL: String = ""
    @AppStorage("authToken") var token: String = ""

    // Data
    @Published var leads: [Lead] = []
    @Published var activities: [Activity] = []
    @Published var tasks: [CRMTask] = []
    @Published var users: [AppUser] = []
    @Published var customers: [Customer] = []
    @Published var projects: [Project] = []
    @Published var projectItems: [ProjectItem] = []

    // UI state
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var banner: Banner?

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var repo: CRMRepository {
        CRMRepository(client: APIClient(baseURL: baseURL, token: token))
    }

    var currentUserId: Int? { JWT.userId(token) }

    var currentUser: AppUser? {
        guard let id = currentUserId else { return nil }
        return users.first { $0.id == id }
    }

    var currentUserName: String {
        currentUser?.name ?? JWT.name(token) ?? "Signed in"
    }

    /// Mirrors canAccessAdminFeatures: CRM edits require role level >= 7.
    /// The server enforces this regardless; this just hides controls.
    var canEdit: Bool {
        guard let role = currentUser?.roleName, let level = ROLE_HIERARCHY[role] else {
            return true // unknown locally -> let the server decide
        }
        return level >= 7
    }

    // MARK: - Loading

    func reload() async {
        guard isConfigured else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let batch = try await repo.loadBatch()
            users = batch.users
            customers = batch.customers
            projects = batch.projects
            projectItems = batch.projectItems
            leads = batch.crmLeads
            activities = batch.crmActivities
            tasks = batch.crmTasks
            hasLoaded = true
        } catch {
            show(error)
        }
    }

    // MARK: - Banner

    func show(_ message: String, isError: Bool = false) {
        banner = Banner(message: message, isError: isError)
        let captured = banner
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if self.banner == captured { self.banner = nil }
        }
    }

    func show(_ error: Error) {
        show((error as? APIError)?.message ?? error.localizedDescription, isError: true)
    }

    // MARK: - Helpers

    func userName(_ id: Int?) -> String {
        guard let id else { return "" }
        return users.first { $0.id == id }?.name ?? ""
    }

    func activityCount(for leadId: Int) -> Int {
        activities.filter { $0.leadId == leadId }.count
    }

    func openTaskCount(for leadId: Int) -> Int {
        tasks.filter { $0.leadId == leadId && $0.status != "done" }.count
    }

    func leadActivities(_ leadId: Int) -> [Activity] {
        activities
            .filter { $0.leadId == leadId }
            .sorted { (Fmt.parse($0.createdAt) ?? .distantPast) > (Fmt.parse($1.createdAt) ?? .distantPast) }
    }

    func leadTasks(_ leadId: Int) -> [CRMTask] {
        tasks
            .filter { $0.leadId == leadId }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                let da = Fmt.parse(a.dueDate) ?? Date.distantFuture
                let db = Fmt.parse(b.dueDate) ?? Date.distantFuture
                return da < db
            }
    }

    // MARK: - Lead KPIs (mirrors renderLeadKpis)

    struct LeadKPIs {
        var openCount = 0
        var totalCount = 0
        var openValue: Double = 0
        var wonCount = 0
        var wonValue: Double = 0
        var openTasks = 0
        var overdueTasks = 0
    }

    var leadKPIs: LeadKPIs {
        var k = LeadKPIs()
        k.totalCount = leads.count
        let open = leads.filter { !["won", "lost"].contains($0.status) }
        k.openCount = open.count
        k.openValue = open.reduce(0) { $0 + Fmt.toNumber($1.estimatedValue) }
        let won = leads.filter { $0.status == "won" }
        k.wonCount = won.count
        k.wonValue = won.reduce(0) { $0 + Fmt.toNumber($1.estimatedValue) }
        let openT = tasks.filter { $0.status != "done" }
        k.openTasks = openT.count
        let today = Calendar.current.startOfDay(for: Date())
        k.overdueTasks = openT.filter {
            if let d = Fmt.parse($0.dueDate) { return d < today }
            return false
        }.count
        return k
    }

    var ownerIds: [Int] {
        Array(Set(leads.compactMap { $0.assignedTo })).sorted()
    }

    // MARK: - Customer relationships (mirrors buildCustomerSummary)

    func customerProjects(_ id: Int) -> [Project] {
        projects.filter { $0.customerId == id }
    }

    func contractValue(projectId: Int) -> Double {
        projectItems
            .filter { $0.projectId == projectId }
            .reduce(0) { $0 + $1.contractQuantity * $1.contractRate }
    }

    /// Completion % for a project. shared.js's getProjectCompletion is not
    /// available, so we use installed vs. contract value (0–100).
    func completion(projectId: Int) -> Double {
        let items = projectItems.filter { $0.projectId == projectId }
        let contract = items.reduce(0) { $0 + $1.contractQuantity * $1.contractRate }
        guard contract > 0 else { return 0 }
        let installed = items.reduce(0) { $0 + $1.installedQuantity * $1.contractRate }
        return min(100, max(0, installed / contract * 100))
    }

    func summary(for customer: Customer) -> CustomerSummary {
        let projs = customerProjects(customer.id)
        let totalValue = projs.reduce(0) { $0 + contractValue(projectId: $1.id) }
        let completions = projs.map { completion(projectId: $0.id) }
        let avg = completions.isEmpty ? 0 : completions.reduce(0, +) / Double(completions.count)
        let segment: String
        if projs.isEmpty { segment = "prospects" }
        else if completions.allSatisfy({ $0 >= 100 }) { segment = "completed" }
        else { segment = "active" }

        var last = customer.createdAt
        for p in projs {
            if let pc = p.createdAt,
               (last == nil || (Fmt.parse(pc) ?? .distantPast) > (Fmt.parse(last) ?? .distantPast)) {
                last = pc
            }
        }
        return CustomerSummary(customer: customer, projects: projs, projectCount: projs.count,
                               totalValue: totalValue, avgCompletion: avg, segment: segment,
                               lastActivity: last)
    }

    var allSummaries: [CustomerSummary] { customers.map { summary(for: $0) } }

    // MARK: - Mutations

    func changeLeadStage(_ leadId: Int, to stageKey: String) async {
        guard canEdit else { return }
        guard let idx = leads.firstIndex(where: { $0.id == leadId }) else { return }
        let previous = leads[idx].status
        guard previous != stageKey else { return }
        leads[idx].status = stageKey          // optimistic
        do {
            _ = try await repo.updateLead(leadId, ["status": stageKey])
            await reload()
        } catch {
            if let i = leads.firstIndex(where: { $0.id == leadId }) { leads[i].status = previous }
            show(error)
        }
    }

    func saveLead(_ input: LeadInput, editingId: Int?) async -> Bool {
        do {
            if let editingId {
                _ = try await repo.updateLead(editingId, input.body)
            } else {
                _ = try await repo.createLead(input)
            }
            await reload()
            show("Lead saved")
            return true
        } catch {
            show(error)
            return false
        }
    }

    func deleteLead(_ id: Int) async -> Bool {
        do {
            try await repo.deleteLead(id)
            await reload()
            show("Lead deleted")
            return true
        } catch {
            show(error)
            return false
        }
    }

    func logActivity(leadId: Int, type: String, note: String) async {
        do {
            _ = try await repo.createActivity(leadId: leadId, type: type, note: note)
            await reload()
            show("Activity logged")
        } catch { show(error) }
    }

    func deleteActivity(_ id: Int) async {
        do {
            try await repo.deleteActivity(id)
            await reload()
        } catch { show(error) }
    }

    func addTask(leadId: Int, title: String, dueDate: String?) async {
        do {
            _ = try await repo.createTask(leadId: leadId, title: title, dueDate: dueDate)
            await reload()
            show("Task added")
        } catch { show(error) }
    }

    func toggleTask(_ id: Int, done: Bool) async {
        do {
            _ = try await repo.updateTask(id, status: done ? "done" : "open")
            await reload()
        } catch { show(error) }
    }

    func deleteTask(_ id: Int) async {
        do {
            try await repo.deleteTask(id)
            await reload()
        } catch { show(error) }
    }
}
