import Foundation
import SwiftUI

enum UsageState: CaseIterable {
    case normal
    case warning
    case critical

    init(remainingPercent: Int) {
        switch remainingPercent {
        case 40...100:
            self = .normal
        case 15...39:
            self = .warning
        default:
            self = .critical
        }
    }

    var color: Color {
        switch self {
        case .normal:
            return Color(nsColor: .systemGreen)
        case .warning:
            return Color(nsColor: .systemYellow)
        case .critical:
            return Color(nsColor: .systemRed)
        }
    }

    var glowColor: Color {
        switch self {
        case .normal:
            return color.opacity(0)
        case .warning:
            return color.opacity(0)
        case .critical:
            return color.opacity(0.3)
        }
    }
}

struct UsageSnapshot: Equatable {
    let title: String
    let remainingPercent: Int
    let usedPercent: Int
    let resetDate: Date?
    let windowDurationMinutes: Int?

    var state: UsageState {
        UsageState(remainingPercent: remainingPercent)
    }

    var progress: Double {
        Double(max(0, min(remainingPercent, 100))) / 100
    }

    var percentText: String {
        "\(max(0, min(remainingPercent, 100)))%"
    }

    var shortWindowTitle: String {
        guard let windowDurationMinutes else {
            return title
        }

        if windowDurationMinutes == 300 {
            return "5h window"
        }

        if windowDurationMinutes == 10080 {
            return "Weekly"
        }

        if windowDurationMinutes < 60 {
            return "\(windowDurationMinutes)m window"
        }

        let hours = windowDurationMinutes / 60
        if hours < 24 {
            return "\(hours)h window"
        }

        let days = hours / 24
        return "\(days)d window"
    }
}

struct UsageDetails: Equatable {
    let tokensUsed: Int64?
    let tokensRemaining: Int64?
    let requestsUsed: Int?
}

struct LimitsPreviewData {
    let hero: UsageSnapshot
    let primary: UsageSnapshot
    let details: UsageDetails
    let planName: String
    let resetSummary: String
    let lastUpdated: Date?
    let lastError: String?

    static let normal = LimitsPreviewData(
        hero: UsageSnapshot(
            title: "Weekly",
            remainingPercent: 72,
            usedPercent: 28,
            resetDate: .now.addingTimeInterval(4 * 3600 + 12 * 60),
            windowDurationMinutes: 10080
        ),
        primary: UsageSnapshot(
            title: "5h window",
            remainingPercent: 93,
            usedPercent: 7,
            resetDate: .now.addingTimeInterval(97 * 60),
            windowDurationMinutes: 300
        ),
        details: UsageDetails(tokensUsed: 720_000, tokensRemaining: 280_000, requestsUsed: 144),
        planName: "Plus",
        resetSummary: "Resets in 4h 12m",
        lastUpdated: .now,
        lastError: nil
    )

    static let warning = LimitsPreviewData(
        hero: UsageSnapshot(
            title: "Weekly",
            remainingPercent: 24,
            usedPercent: 76,
            resetDate: .now.addingTimeInterval(89 * 60),
            windowDurationMinutes: 10080
        ),
        primary: UsageSnapshot(
            title: "5h window",
            remainingPercent: 41,
            usedPercent: 59,
            resetDate: .now.addingTimeInterval(21 * 60),
            windowDurationMinutes: 300
        ),
        details: UsageDetails(tokensUsed: 1_520_000, tokensRemaining: 480_000, requestsUsed: 328),
        planName: "Pro",
        resetSummary: "Resets in 1h 29m",
        lastUpdated: .now,
        lastError: nil
    )

    static let critical = LimitsPreviewData(
        hero: UsageSnapshot(
            title: "Weekly",
            remainingPercent: 9,
            usedPercent: 91,
            resetDate: .now.addingTimeInterval(28 * 60),
            windowDurationMinutes: 10080
        ),
        primary: UsageSnapshot(
            title: "5h window",
            remainingPercent: 13,
            usedPercent: 87,
            resetDate: .now.addingTimeInterval(11 * 60),
            windowDurationMinutes: 300
        ),
        details: UsageDetails(tokensUsed: nil, tokensRemaining: nil, requestsUsed: nil),
        planName: "Plus",
        resetSummary: "Resets in 28m",
        lastUpdated: .now,
        lastError: "Detailed token stats are unavailable from the current Codex app-server payload."
    )
}
