# LSEC CRM — iOS app

A native SwiftUI iOS port of the web **CRM – Construction Management** page
(`crm.html`). It is a faithful 1:1 of that screen and talks to the **same
backend and the same Neon Postgres database** the web app uses.

## How it connects to "the same database"

The web app does not talk to Neon directly from the browser. It calls a REST
API (`api.js`, a Netlify function) which runs on top of Neon Postgres
(`const sql = neon(process.env.DATABASE_URL)`). Every CRM action on the page
goes through that API:

| Web page action            | Endpoint used                              |
| -------------------------- | ------------------------------------------ |
| Load all data (`/batch`)   | `GET /api/batch`                           |
| Add / edit lead            | `POST /api/crm-leads`, `PUT /api/crm-leads/:id` |
| Drag / change stage        | `PUT /api/crm-leads/:id` `{status}`        |
| Delete lead                | `DELETE /api/crm-leads/:id`                |
| Log activity               | `POST /api/crm-leads/:id/activities`       |
| Delete activity            | `DELETE /api/crm-activities/:id`           |
| Add follow-up task         | `POST /api/crm-leads/:id/tasks`            |
| Toggle / delete task       | `PUT` / `DELETE /api/crm-tasks/:id`        |

This iOS app calls the **exact same endpoints**, so it reads and writes the
same rows in the same database. Going through the API (rather than opening a
raw Postgres connection from the phone) is also what keeps the backend's auth
and role checks intact — and it avoids shipping `DATABASE_URL` inside a mobile
binary, which would expose full database credentials to anyone who installs
the app.

## Setup

1. Open `LSEC_CRM.xcodeproj` in Xcode 15+ and run on an iOS 16+ simulator or
   device.
2. On first launch you land on **Settings**. Provide:
   - **API Base URL** — your site origin plus `/api`, e.g.
     `https://yoursite.com/api` (the same origin the web app's `api` object
     uses).
   - **Authentication** — either:
     - **Paste Token**: paste the Bearer JWT the web app stores after login.
       In the web app you can read it from the browser console / local
       storage (it's the token sent as `Authorization: Bearer …`).
     - **Sign In**: enter your auth endpoint URL plus email/password. The app
       POSTs `{email, password}` and reads the `token` field from the
       response. (The login route is a separate function from `api.js`, so its
       URL is configurable here.)
3. Tap **Save & Connect**. The app loads `/batch` and renders the pipeline.

The base URL and token persist between launches. Use **Sign Out** in Settings
to clear the token.

## What's implemented (matches `crm.html`)

- **Lead KPI summary** — Open Leads, Open Pipeline Value, Won, Open Follow-ups
  (with overdue count).
- **Sales Pipeline** — the six stages (New, Contacted, Qualified, Proposal,
  Won, Lost) as a horizontally scrolling board with per-column counts and
  values, live search, and an owner filter. Each card shows company, value,
  activity/task chips and the owner's initials. Tap a card's stage chip to
  change stage (the touch equivalent of the web drag-and-drop); the update is
  optimistic and reverts on failure.
- **Add / Edit Lead** — full form (name, company, email, phone, stage,
  estimated value, source, assigned to, linked customer, notes).
- **Lead Detail** — gradient header, **Activity Log** (note/call/email/meeting
  with add + delete) and **Follow-up Tasks** (add with due date, toggle
  done/overdue, delete), plus Edit and Delete Lead.
- **Customer Relationships** — cards derived from `customers` + `projects` +
  `project_items`, with search, segment filter (Prospect / Active / Completed),
  sort (Pipeline Value / Most Projects / Name / Most Recent), an average
  completion bar, and a detail sheet listing each project's contract value and
  completion.
- **Role gating** — editing controls are hidden when the signed-in user's role
  is below the CRM edit threshold (level 7), matching the web app. The server
  enforces this regardless.

## Notes / assumptions

- `shared.js`'s `getProjectCompletion()` was not provided, so project
  completion is computed as installed value ÷ contract value (0–100%) from
  `project_items` (`installed_quantity`, `contract_quantity`, `contract_rate`).
  Adjust `AppStore.completion(projectId:)` if your definition differs.
- Postgres serialises `DECIMAL`/`NUMERIC` as strings and `INTEGER` as numbers;
  the model decoders accept either representation.
- The project uses Xcode-generated Info.plist settings (SwiftUI app lifecycle),
  so there is no checked-in `Info.plist` or asset catalog.

## File map

| File | Responsibility |
| ---- | -------------- |
| `LSEC_CRMApp.swift` | App entry point |
| `RootView.swift` | Tab shell + connect gate + toast banner |
| `AppStore.swift` | Observable state, loading, mutations, derived KPIs/summaries |
| `NeonClient.swift` | REST client to the Neon-backed API + JWT helper |
| `CRMRepository.swift` | Typed wrappers for the CRM endpoints |
| `Models.swift` | Codable models + flexible decoders + stage definitions |
| `Formatters.swift` | Currency/date formatting, color theme |
| `Components.swift` | Reusable views (badges, KPI cards, headers) |
| `PipelineView.swift` | KPIs + pipeline board + lead cards |
| `LeadEditView.swift` | Add/Edit lead form |
| `LeadDetailView.swift` | Activity log + tasks |
| `CustomerListView.swift` | Customer relationship cards |
| `CustomerDetailView.swift` | Customer project breakdown |
| `SettingsView.swift` | Connection + auth |
