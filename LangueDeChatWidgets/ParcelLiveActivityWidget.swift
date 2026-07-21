import ActivityKit
import WidgetKit
import SwiftUI

private extension ParcelActivityAttributes {
    static let preview = ParcelActivityAttributes(
        trackingNumber: "1234567890123",
        carrierName: "Yamato Transport",
        parcelTitle: "Yamato Transport"
    )
}

private extension ParcelActivityAttributes.ContentState {
    static let inTransit = ParcelActivityAttributes.ContentState(
        status: "持ち出し中",
        isDelivered: false,
        progressStep: 3,
        lastUpdated: Date()
    )
    static let delivered = ParcelActivityAttributes.ContentState(
        status: "配達完了",
        isDelivered: true,
        progressStep: 4,
        lastUpdated: Date()
    )
}

// MARK: - Widget

struct ParcelLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParcelActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
                        Text(context.attributes.carrierName)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isDelivered ? "Delivered" : "In Transit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(context.state.isDelivered ? Color.green : Color.accentColor)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(context.state.status)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        DeliveryProgressBar(step: context.state.progressStep)

                        HStack {
                            Text(context.attributes.trackingNumber)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 8)
                            Text("Updated \(context.state.lastUpdated, style: .time)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.accentColor)
            } compactTrailing: {
                if context.state.isDelivered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                } else {
                    DeliveryProgressRing(step: context.state.progressStep)
                        .frame(width: 20, height: 20)
                }
            } minimal: {
                if context.state.isDelivered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                } else {
                    DeliveryProgressRing(step: context.state.progressStep, lineWidth: 2.5)
                        .frame(width: 18, height: 18)
                }
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    @Environment(\.activityFamily) private var activityFamily
    let context: ActivityViewContext<ParcelActivityAttributes>

    var body: some View {
        switch activityFamily {
        case .small:
            watchView
        default:
            phoneView
        }
    }

    // iPhone Lock Screen / StandBy presentation.
    private var phoneView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Image(systemName: context.state.isDelivered ? "checkmark.circle.fill" : "shippingbox.fill")
                    .foregroundStyle(context.state.isDelivered ? Color.green : Color.accentColor)
                Text(context.attributes.parcelTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(context.attributes.trackingNumber)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Text(context.state.status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            DeliveryProgressBar(step: context.state.progressStep)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // Apple Watch Smart Stack (`.small`). The system draws the app-name
    // header above this, so lead with what's actually useful: which parcel,
    // its current carrier status, and how far along it is.
    private var watchView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: context.state.isDelivered ? "checkmark.circle.fill" : "shippingbox.fill")
                    .foregroundStyle(context.state.isDelivered ? Color.green : Color.accentColor)
                Text(context.attributes.parcelTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(context.state.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            DeliveryProgressBar(step: context.state.progressStep)
                .padding(.top, 2)

            Text(context.state.isDelivered ? "Delivered" : "In Transit")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(context.state.isDelivered ? Color.green : Color.accentColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Progress Bar

struct DeliveryProgressBar: View {
    let step: Int

    private let totalSteps = 5
    private let maxBarHeight: CGFloat = 10

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(i <= step ? activeColor : Color.secondary.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight(for: i))
            }
        }
        .frame(height: maxBarHeight)
    }

    private func barHeight(for index: Int) -> CGFloat { maxBarHeight }

    private var activeColor: Color {
        step == totalSteps - 1 ? .green : .accentColor
    }
}

// MARK: - Progress Ring

/// Compact circular counterpart to `DeliveryProgressBar`, used in the
/// Dynamic Island compact/minimal presentations and the Apple Watch Smart
/// Stack. The ring fills as the parcel advances toward delivery, so the
/// state reads as "how far along" instead of an ambiguous dotted circle.
struct DeliveryProgressRing: View {
    let step: Int
    var lineWidth: CGFloat = 3

    private let totalSteps = 5

    private var fraction: Double {
        let clamped = min(max(step + 1, 0), totalSteps)
        return Double(clamped) / Double(totalSteps)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Previews

#Preview("Lock Screen — In Transit", as: .content, using: ParcelActivityAttributes.preview) {
    ParcelLiveActivityWidget()
} contentStates: {
    ParcelActivityAttributes.ContentState.inTransit
    ParcelActivityAttributes.ContentState.delivered
}
