import SwiftUI
import SwiftData
import TsuiseKit

struct AddParcelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var trackingNumber: String = ""
    @State private var carrier: Carrier = .japanPost
    @State private var nickname: String = ""
    @State private var notes: String = ""
    @State private var orderURL: String = ""
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Carrier", selection: $carrier) {
                        ForEach(Carrier.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    TextField("Tracking Number", text: $trackingNumber)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                    TextField("Nickname (optional)", text: $nickname)
                }

                Section("Details (optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Order URL", text: $orderURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Add Parcel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task { await add() }
                        }
                        .disabled(trackingNumber.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func add() async {
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }

        let trimmed = trackingNumber.trimmingCharacters(in: .whitespaces)
        let parcel = TrackedParcel(
            trackingNumber: trimmed,
            carrier: carrier,
            nickname: nickname.isEmpty ? nil : nickname,
            notes: notes.isEmpty ? nil : notes,
            orderURL: orderURL.isEmpty ? nil : orderURL.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(parcel)

        do {
            try await ParcelRefresher.shared.refresh(parcel)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(parcel)
            errorMessage = "Failed to fetch: \(error.localizedDescription)"
        }
    }
}
