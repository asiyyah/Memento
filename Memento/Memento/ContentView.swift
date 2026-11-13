import SwiftUI

/// The steps that follow Pick photos in the Make flow.
enum MakeStep: Hashable {
    case chooseComposition
}

/// App root. For the first slice this is the Make flow on its own.
struct ContentView: View {
    @State private var session = MakeSession()
    @State private var path: [MakeStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            PickPhotosView(session: session) {
                path.append(.chooseComposition)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MakeStep.self) { step in
                switch step {
                case .chooseComposition:
                    ChooseCompositionPlaceholder(photoCount: session.photos.count)
                }
            }
        }
        .tint(Theme.ink)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
