//
//  Formatters.swift
//  LSEC_CRM
//
//  Equivalents of the web app's formatCurrency / formatDate / formatDateTime
//  and the numeric coercion used throughout crm.html.
//

import Foundation
import SwiftUI

enum Fmt {
    static func toNumber(_ value: Double?) -> Double { value ?? 0 }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    static func currency(_ value: Double?) -> String {
        currencyFormatter.string(from: NSNumber(value: value ?? 0)) ?? "$0"
    }

    // Parses the timestamp / date strings returned by Postgres via the API.
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }

        // ISO8601 with/without fractional seconds.
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }

        for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss.SSSZ",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(identifier: "UTC")
            df.dateFormat = fmt
            if let d = df.date(from: raw) { return d }
        }
        // Date-only fallback (first 10 chars).
        if raw.count >= 10 {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: String(raw.prefix(10))) { return d }
        }
        return nil
    }

    private static let dateOut: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let dateTimeOut: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy h:mm a"
        return f
    }()

    static func date(_ raw: String?) -> String {
        guard let d = parse(raw) else { return "N/A" }
        return dateOut.string(from: d)
    }

    static func dateTime(_ raw: String?) -> String {
        guard let d = parse(raw) else { return "" }
        return dateTimeOut.string(from: d)
    }

    static func initials(_ name: String?) -> String {
        let parts = (name ?? "?").split(separator: " ")
        let letters = parts.compactMap { $0.first }
        return String(letters).uppercased().prefix(2).description
    }
}

// Hex color helper (mirrors the CSS palette used in crm.html).
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

// Shared palette approximating the web theme variables.
enum Theme {
    static let dark = Color(hex: 0x18181b)
    static let surface = Color(.systemBackground)
    static let surfaceHover = Color(hex: 0xf4f4f5)
    static let border = Color(hex: 0xe4e4e7)
    static let muted = Color(hex: 0x71717a)
    static let secondary = Color(hex: 0x52525b)
    static let danger = Color(hex: 0xef4444)
    static let warning = Color(hex: 0xf59e0b)
    static let info = Color(hex: 0x3b82f6)
    static let success = Color(hex: 0x22c55e)

    static let headerGradient = LinearGradient(
        colors: [Color(hex: 0x18181b), Color(hex: 0x27272a), Color(hex: 0x3f3f46)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
