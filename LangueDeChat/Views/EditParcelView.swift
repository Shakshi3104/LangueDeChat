import SwiftUI
import SwiftData
import TsuiseKit

struct EditParcelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let parcel: TrackedParcel

    @State private var nickname: String
    @State private var notes: String
    @State private var orderURL: String

    init(parcel: TrackedParcel) {
        self.parcel = parcel
        _nickname = State(initialValue: parcel.nickname ?? "")
        _notes = State(initialValue: parcel.notes ?? "")
        _orderURL = State(initialValue: parcel.orderURL ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Carrier", value: parcel.carrier.displayName)
                    LabeledContent("Tracking Number") {
                        Text(parcel.trackingNumber)
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField("Nickname", text: $nickname)
                }

                Section("Details") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                    TextField("Order URL", text: $orderURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Edit Parcel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        parcel.nickname = trimmedOrNil(nickname)
        parcel.notes = trimmedOrNil(notes)
        parcel.orderURL = trimmedOrNil(orderURL)
        try? modelContext.save()
        dismiss()
    }

    private func trimmedOrNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
