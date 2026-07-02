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
                    Label(context.attributes.carrierName, systemImage: "shippingbox.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isDelivered ? "Delivered" : "In Transit")
                        .font(.caption.bold())
                        .foregroundStyle(context.state.isDelivered ? Color.green : Color.accentColor)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DeliveryProgressBar(step: context.state.progressStep)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.accentColor)
            } compactTrailing: {
                Image(systemName: context.state.isDelivered ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(context.state.isDelivered ? Color.green : Color.accentColor)
            } minimal: {
                Image(systemName: context.state.isDelivered ? "checkmark.circle.fill" : "shippingbox.fill")
                    .foregroundStyle(context.state.isDelivered ? Color.green : Color.accentColor)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ParcelActivityAttributes>

    var body: some View {
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

// MARK: - Previews

#Preview("Lock Screen — In Transit", as: .content, using: ParcelActivityAttributes.preview) {
    ParcelLiveActivityWidget()
} contentStates: {
    ParcelActivityAttributes.ContentState.inTransit
    ParcelActivityAttributes.ContentState.delivered
}
