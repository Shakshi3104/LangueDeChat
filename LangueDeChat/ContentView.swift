import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ParcelListView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TrackedParcel.self, inMemory: true)
}
