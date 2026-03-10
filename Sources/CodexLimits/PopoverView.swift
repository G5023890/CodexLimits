import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: LimitStore
    let onRefresh: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            heroGauge
            statsGrid
            secondaryCard
            footer
        }
        .padding(15)
        .frame(width: 326)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 10)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = AppAssets.appIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Limits")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(store.heroResetSummary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.planName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
    }

    private var heroGauge: some View {
        HStack(spacing: 14) {
            ZStack {
                UsageGaugeView(snapshot: store.heroSnapshot, style: .popover, glow: true)

                VStack(spacing: 2) {
                    Text(store.heroSnapshot.percentText)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("remaining")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                }
            }

                VStack(alignment: .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.heroSnapshot.shortWindowTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text(store.relativeResetText(for: store.heroSnapshot.resetDate))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                stateBadge(for: store.heroSnapshot)

                if let error = store.lastError {
                    Text(error)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let updated = store.lastUpdatedText {
                    Text("Updated \(updated)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.055), lineWidth: 0.8)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            statCard(title: "Tokens used", value: store.tokensUsedText)
            statCard(title: "Remaining", value: store.tokensRemainingText)
            statCard(title: "Requests", value: store.requestsUsedText)
            statCard(title: "Plan", value: store.planName)
        }
    }

    private var secondaryCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.primarySnapshot.shortWindowTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))

                Spacer()

                Text(store.primarySnapshot.percentText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                UsageGaugeView(snapshot: store.primarySnapshot, style: .menuBar)
                Text(store.primaryResetSummary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.8)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Refresh", action: onRefresh)
                .buttonStyle(PopoverActionButtonStyle(prominent: true))

            Button("Quit", action: onQuit)
                .buttonStyle(PopoverActionButtonStyle(prominent: false))
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.8)
        }
    }

    private func stateBadge(for snapshot: UsageSnapshot) -> some View {
        let title: String
        switch snapshot.state {
        case .normal:
            title = "Healthy"
        case .warning:
            title = "Warning"
        case .critical:
            title = "Critical"
        }

        return Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(snapshot.state.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(snapshot.state.color.opacity(0.12), in: Capsule())
    }
}

private struct PopoverActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(background(configuration: configuration), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor(configuration: configuration), lineWidth: 0.7)
            }
    }

    private func background(configuration: Configuration) -> Color {
        if prominent {
            return Color.accentColor.opacity(configuration.isPressed ? 0.18 : 0.11)
        }

        return Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04)
    }

    private func borderColor(configuration: Configuration) -> Color {
        if prominent {
            return Color.accentColor.opacity(configuration.isPressed ? 0.22 : 0.14)
        }

        return Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06)
    }
}
