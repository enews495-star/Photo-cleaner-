import SwiftUI

@main
struct PhotoCleanerApp: App {
    @State private var library = PhotoLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
    }
}
