import SwiftUI
import SwiftData
import TsuiseKit

struct ParcelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let parcel: TrackedParcel
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 16)

                Divider()

                if let info = parcel.cachedInfo, !info.events.isEmpty {
                    ForEach(Array(info.events.reversed().enumerated()), id: \.offset) { _, event in
                        EventRow(event: event)
                            .padding(.vertical, 12)
                        Divider()
                    }
                } else {
                    Text(isRefreshing ? "Loading…" : "No tracking information yet")
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if let url = trackingURL { openURL(url) }
                } label: {
                    Image(systemName: "safari")
                }
                Menu {
                    Button { Task { await refresh() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        modelContext.delete(parcel)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .task {
            await refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(parcel.displayName)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            HStack {
                Text(parcel.trackingNumber)
                    .font(.body.monospaced())
                    .foregroundColor(.accentColor)
                Spacer()
                Text(parcel.carrier.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let info = parcel.cachedInfo, let eta = info.estimatedDelivery {
                Label(eta, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            if let delivered = parcel.deliveredAt {
                Label {
                    Text(delivered, format: .dateTime
                        .year().month().day().hour().minute()
                        .locale(Locale(identifier: "en_US_POSIX")))
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if let notes = parcel.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.top, 8)
            }
            if let url = parcel.orderURLValue {
                Link(destination: url) {
                    Label("View order", systemImage: "link")
                        .font(.subheadline)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

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
}

private struct EventRow: View {
    let event: TrackingEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.rawDate)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(event.status)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}
