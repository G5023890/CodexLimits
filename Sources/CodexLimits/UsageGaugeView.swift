import SwiftUI

struct UsageGaugeView: View {
    enum GaugeStyle {
        case menuBar
        case popover

        var size: CGFloat {
            switch self {
            case .menuBar:
                return 18
            case .popover:
                return 96
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .menuBar:
                return 2.6
            case .popover:
                return 8
            }
        }

        var glowRadius: CGFloat {
            switch self {
            case .menuBar:
                return 0
            case .popover:
                return 6
            }
        }

        var trackOpacity: Double {
            switch self {
            case .menuBar:
                return 0.15
            case .popover:
                return 0.1
            }
        }
    }

    let snapshot: UsageSnapshot
    let style: GaugeStyle
    var glow: Bool = false

    var body: some View {
        let outerPadding = style.lineWidth / 2 + (glow ? style.glowRadius : 0)
        let drawingSize = max(1, style.size - outerPadding * 2)

        ZStack {
            Circle()
                .stroke(
                    Color.primary.opacity(style.trackOpacity),
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: snapshot.progress)
                .stroke(
                    snapshot.state.color,
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: glow ? snapshot.state.glowColor : .clear,
                    radius: glow ? style.glowRadius : 0,
                    x: 0,
                    y: 0
                )
        }
        .frame(width: drawingSize, height: drawingSize)
        .frame(width: style.size, height: style.size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(snapshot.title) remaining"))
        .accessibilityValue(Text(snapshot.percentText))
    }
}

struct StatusItemView: View {
    let snapshot: UsageSnapshot
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            UsageGaugeView(snapshot: snapshot, style: .menuBar)

            Text(snapshot.percentText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 34, alignment: .leading)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(isActive ? 0.14 : 0.06), lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Codex limits"))
        .accessibilityValue(Text("\(snapshot.title) \(snapshot.percentText) remaining"))
    }

    private var backgroundColor: Color {
        isActive ? Color.primary.opacity(0.12) : Color.clear
    }
}
