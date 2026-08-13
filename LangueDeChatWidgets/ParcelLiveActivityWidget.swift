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

                        DeliveryRouteView(step: context.state.progressStep,
                                          isDelivered: context.state.isDelivered)

                        HStack {
                            Text(context.attributes.trackingNumber)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("Updated \(context.state.lastUpdated, style: .time)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 6)
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

            DeliveryRouteView(step: context.state.progressStep,
                              isDelivered: context.state.isDelivered)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Delivery Route

/// Rocket Now–style route: three fixed node badges — origin depot
/// (`building.2`) → store/center (`storefront`) → home (`house`) —
/// joined by a track that fills as the parcel advances. The 5-stage
/// `progressStep` maps onto the three stops at 0 / 0.5 / 1.0, so
/// "out for delivery" sits just short of home and "delivered" arrives.
struct DeliveryRouteView: View {
    let step: Int
    var isDelivered: Bool = false

    private let totalSteps = 5

    /// 0…1 position of the parcel along the whole route.
    private var progress: CGFloat {
        CGFloat(min(max(step, 0), totalSteps - 1)) / CGFloat(totalSteps - 1)
    }

    private var tint: Color { isDelivered ? .green : .accentColor }

    private struct Stop { let at: CGFloat; let icon: String }
    private let stops = [
        Stop(at: 0.0, icon: "building.2.fill"),
        Stop(at: 0.5, icon: "storefront.fill"),
        Stop(at: 1.0, icon: "house.fill"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(stops.indices, id: \.self) { i in
                nodeBadge(stops[i], isEnd: i == stops.count - 1)
                if i < stops.count - 1 {
                    segment(from: stops[i].at, to: stops[i + 1].at)
                }
            }
        }
        .frame(height: 30)
    }

    private func nodeBadge(_ stop: Stop, isEnd: Bool) -> some View {
        let passed = progress >= stop.at - 0.001
        let icon = (isEnd && isDelivered) ? "checkmark.circle.fill" : stop.icon
        return Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(passed ? tint : Color.secondary)
            .frame(width: 30, height: 30)
            .background(Circle().fill(passed ? tint.opacity(0.15) : Color.secondary.opacity(0.12)))
            .overlay(Circle().strokeBorder(passed ? tint.opacity(0.5) : Color.clear, lineWidth: 1))
    }

    private func segment(from: CGFloat, to: CGFloat) -> some View {
        let fill = min(max((progress - from) / (to - from), 0), 1)
        return ZStack(alignment: .leading) {
            // Remaining route — dashed, like Rocket Now.
            TrackLine()
                .stroke(Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4]))
            // Completed route — solid fill.
            GeometryReader { g in
                Capsule().fill(tint).frame(width: g.size.width * fill)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 3)
    }
}

/// A single horizontal line through the vertical center — the dashed
/// backbone of `DeliveryRouteView`'s segments.
private struct TrackLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Progress Ring

/// Compact circular counterpart to `DeliveryRouteView`, used in the
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
