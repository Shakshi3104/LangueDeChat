import SwiftUI

/// Carrier choices shown in the share-sheet form. Duplicated locally (raw value +
/// English display name) so the extension links nothing but system frameworks —
/// the raw values must stay in sync with `TsuiseKit.Carrier`.
private struct ShareCarrier: Identifiable, Hashable {
    let raw: String
    let name: String
    var id: String { raw }

    static let all = [
        ShareCarrier(raw: "japanpost", name: "Japan Post"),
        ShareCarrier(raw: "yamato", name: "Yamato Transport"),
        ShareCarrier(raw: "sagawa", name: "Sagawa Express"),
    ]
}

/// Confirmation form hosted inside the share sheet. Pre-filled from the parser;
/// the user can correct the carrier / number before adding.
struct ShareFormView: View {
    let initialCarrier: String?
    let initialTrackingNumber: String
    /// Returns `true` if the parcel was added, `false` if it's already tracked.
    let onAdd: (_ carrierRaw: String, _ trackingNumber: String, _ nickname: String?) -> Bool
    let onCancel: () -> Void

    @State private var carrier: String
    @State private var trackingNumber: String
    @State private var nickname: String = ""
    @State private var alreadyTracked = false

    init(
        initialCarrier: String?,
        initialTrackingNumber: String,
        onAdd: @escaping (_ carrierRaw: String, _ trackingNumber: String, _ nickname: String?) -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.initialCarrier = initialCarrier
        self.initialTrackingNumber = initialTrackingNumber
        self.onAdd = onAdd
        self.onCancel = onCancel
        _carrier = State(initialValue: initialCarrier ?? ShareCarrier.all[0].raw)
        _trackingNumber = State(initialValue: initialTrackingNumber)
    }

    private var trimmedNumber: String {
        trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Carrier", selection: $carrier) {
                        ForEach(ShareCarrier.all) { option in
                            Text(option.name).tag(option.raw)
                        }
                    }
                    TextField("Tracking Number", text: $trackingNumber)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .onChange(of: trackingNumber) { alreadyTracked = false }
                    TextField("Nickname (optional)", text: $nickname)
                } footer: {
                    if alreadyTracked {
                        Text("This parcel is already being tracked in LangueDeChat.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Added to LangueDeChat. Open the app to see tracking details.")
                    }
                }
            }
            .navigationTitle("Add Parcel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // onAdd dismisses on success; a false result means the
                        // parcel is already tracked, so surface that instead.
                        alreadyTracked = !onAdd(carrier, trimmedNumber, nickname.isEmpty ? nil : nickname)
                    }
                    .disabled(trimmedNumber.isEmpty)
                }
            }
            .onChange(of: carrier) { alreadyTracked = false }
        }
    }
}
