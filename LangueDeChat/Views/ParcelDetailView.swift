import SwiftUI
import SwiftData
import TsuiseKit

struct ParcelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let parcel: TrackedParcel
    @State private var isRefreshing = false
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                if hasMeta {
                    metaCard
                }
                eventsCard
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refresh()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if let url = trackingURL { openURL(url) }
                } label: {
                    Image(systemName: "safari")
                }
                Menu {
                    Button { showingEdit = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button { Task { await refresh() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditParcelView(parcel: parcel)
        }
        .alert(
            "Delete this parcel?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(parcel)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(parcel.titleText) and its tracking history will be removed from this device.")
        }
        .task {
            await refresh()
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(parcel.displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack {
                Text(parcel.trackingNumber)
                    .font(.body.monospaced())
                    .foregroundColor(.accentColor)
                    .textSelection(.enabled)
                Spacer()
                Text(parcel.carrier.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            statusPills
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var statusPills: some View {
        let info = parcel.cachedInfo
        let eta = info?.estimatedDelivery
        if eta != nil || parcel.deliveredAt != nil {
            HStack(spacing: 8) {
                if let delivered = parcel.deliveredAt {
                    Pill(
                        icon: "checkmark.seal.fill",
                        text: "Delivered \(Self.shortFormatter.string(from: delivered))",
                        tint: .green
                    )
                } else if let eta {
                    Pill(
                        icon: "clock.fill",
                        text: eta,
                        tint: .accentColor
                    )
                }
            }
        }
    }

    // MARK: - Meta (notes + order link)

    private var hasMeta: Bool {
        (parcel.notes?.isEmpty == false) || parcel.orderURLValue != nil
    }

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let notes = parcel.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let url = parcel.orderURLValue {
                Link(destination: url) {
                    Label("View order", systemImage: "link")
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Events timeline

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let info = parcel.cachedInfo, !info.events.isEmpty {
                let ordered = Array(info.events.reversed().enumerated())
                ForEach(ordered, id: \.offset) { index, event in
                    TimelineEventRow(
                        event: event,
                        isLatest: index == 0,
                        isFirst: index == 0,
                        isLast: index == ordered.count - 1
                    )
                }
            } else {
                Text(isRefreshing ? "Loading…" : "No tracking information yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Helpers

    private var trackingURL: URL? {
        switch parcel.carrier {
        case .japanPost:
            URL(string: "https://trackings.post.japanpost.jp/services/srv/search/direct?reqCodeNo1=\(parcel.trackingNumber)&searchKind=S004&locale=ja")
        case .yamato:
            URL(string: "https://toi.kuronekoyamato.co.jp/cgi-bin/tneko?init=yes&number01=\(parcel.trackingNumber)")
        case .sagawa:
            URL(string: "https://k2k.sagawa-exp.co.jp/p/sagawa/web/okurijoinput.jsp")
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        try? await ParcelRefresher.shared.refresh(parcel)
        try? modelContext.save()
    }

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f
    }()
}

// MARK: - Pill

private struct Pill: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(tint.opacity(0.15))
            )
    }
}

// MARK: - Timeline row

private struct TimelineEventRow: View {
    let event: TrackingEvent
    let isLatest: Bool
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            timelineColumn
            contentColumn
        }
    }

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            // Above the dot
            Rectangle()
                .fill(isFirst ? Color.clear : lineColor)
                .frame(width: 2, height: 6)
            // Dot
            ZStack {
                if isLatest {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 6)
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .stroke(lineColor, lineWidth: 2)
                        .frame(width: 11, height: 11)
                }
            }
            // Below the dot
            Rectangle()
                .fill(isLast ? Color.clear : lineColor)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 20)
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.rawDate)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(event.status)
                .font(isLatest ? .title3.bold() : .body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.bottom, isLast ? 0 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lineColor: Color {
        Color.secondary.opacity(0.3)
    }
}
