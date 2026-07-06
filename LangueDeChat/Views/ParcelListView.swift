import SwiftUI
import SwiftData
import TsuiseKit

enum ParcelFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case inProgress = "In Progress"
    case delivered = "Delivered"

    var id: Self { self }
}

struct ParcelListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TrackedParcel.addedAt, order: .reverse) private var parcels: [TrackedParcel]
    @State private var showingAdd = false
    @State private var isRefreshing = false
    @State private var filter: ParcelFilter = .all
    @State private var parcelToDelete: TrackedParcel?

    private var filteredParcels: [TrackedParcel] {
        switch filter {
        case .all:        parcels
        case .inProgress: parcels.filter { $0.progressStep != .delivered }
        case .delivered:  parcels.filter { $0.progressStep == .delivered }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(filteredParcels) { parcel in
                    NavigationLink(value: parcel) {
                        ParcelRow(parcel: parcel)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            parcelToDelete = parcel
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refreshAll()
        }
        .overlay {
            if parcels.isEmpty {
                ContentUnavailableView(
                    "No parcels yet",
                    systemImage: "shippingbox",
                    description: Text("Tap + to track a new parcel.")
                )
            } else if filteredParcels.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("No parcels match this filter.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $filter) {
                        ForEach(ParcelFilter.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: filter == .all
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .navigationTitle("Deliveries")
        .navigationDestination(for: TrackedParcel.self) { parcel in
            ParcelDetailView(parcel: parcel)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: Circle())
                    .foregroundColor(.white)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showingAdd) {
            AddParcelView()
        }
        .alert(
            "Delete this parcel?",
            isPresented: Binding(
                get: { parcelToDelete != nil },
                set: { if !$0 { parcelToDelete = nil } }
            ),
            presenting: parcelToDelete
        ) { parcel in
            Button("Delete", role: .destructive) {
                modelContext.delete(parcel)
            }
            Button("Cancel", role: .cancel) {}
        } message: { parcel in
            Text("\(parcel.titleText) and its tracking history will be removed from this device.")
        }
        .task {
            await PendingParcelImporter.importPending(into: modelContext)
            // Sync activities from cache first so a stale one is corrected
            // immediately, even before (or without) a successful network fetch.
            await LiveActivityManager.shared.reconcile(with: parcels)
            await refreshAll()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await PendingParcelImporter.importPending(into: modelContext)
                await LiveActivityManager.shared.reconcile(with: parcels)
                await refreshAll()
            }
        }
    }

    private func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await ParcelRefresher.shared.refreshAll(in: modelContext)
    }
}

private struct ParcelRow: View {
    let parcel: TrackedParcel

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(parcel.titleText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(parcel.currentStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(parcel.dateText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.accentColor.opacity(0.18))
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: iconName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.accentColor)
            )
    }

    private var iconName: String {
        switch parcel.carrier {
        case .japanPost: "shippingbox.fill"
        case .yamato:    "truck.box.fill"
        case .sagawa:    "box.truck.fill"
        }
    }
}
