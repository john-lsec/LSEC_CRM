//
//  Components.swift
//  LSEC_CRM
//
//  Small reusable views matching the web styling (badges, KPI cards, headers).
//

import SwiftUI

// MARK: - Badge

struct Badge: View {
    let text: String
    var background: Color = Theme.muted
    var foreground: Color = .white

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .foregroundColor(foreground)
            .clipShape(Capsule())
    }
}

func segmentBadge(_ segment: String) -> Badge {
    switch segment {
    case "active":    return Badge(text: "Active", background: Theme.info)
    case "completed": return Badge(text: "Completed", background: Theme.success)
    default:          return Badge(text: "Prospect", background: Theme.warning)
    }
}

// MARK: - KPI card (mirrors .crm-kpi)

struct KPICard: View {
    let label: String
    let value: String
    let sub: String
    var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2)
                .tracking(0.5)
                .foregroundColor(accent ? .white.opacity(0.7) : Theme.muted)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(accent ? .white : Theme.dark)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(sub)
                .font(.caption2)
                .foregroundColor(accent ? .white.opacity(0.7) : Theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            if accent { Theme.headerGradient }
            else { Theme.surface }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent ? Color.clear : Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Dark gradient header used in detail screens (.crm-customer-header)

struct GradientHeader<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.headerGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Card container (.card / .crm-card)

struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Toast banner (mirrors showAlert)

struct BannerView: View {
    let banner: Banner
    var body: some View {
        Text(banner.message)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(banner.isError ? Theme.danger : Theme.success)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Text(icon).font(.system(size: 44)).opacity(0.5)
            Text(message)
                .font(.subheadline)
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Mini chip used on lead cards

struct MiniChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(Theme.secondary)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Theme.surfaceHover)
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            .clipShape(Capsule())
    }
}
