import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var prefill: AddParcelPrefill?

    var body: some View {
        NavigationStack {
            ParcelListView()
        }
        .onOpenURL { url in
            if let parsed = DeepLink.parseAdd(url) {
                prefill = parsed
            }
        }
        .sheet(item: $prefill) { prefill in
            AddParcelView(prefill: prefill)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TrackedParcel.self, inMemory: true)
}
