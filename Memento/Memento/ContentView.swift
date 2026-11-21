import SwiftUI

/// The steps that follow Pick photos in the Make flow.
enum MakeStep: Hashable {
    case chooseComposition
    case edit(CompositionStyle)
    case preview(CompositionStyle)
}

/// App root. For the first slice this is the Make flow on its own.
struct ContentView: View {
    @State private var session = MakeSession()
    @State private var path: [MakeStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            PickPhotosView(session: session) {
                session.prepareCompositions()
                path.append(.chooseComposition)
            }
            .navigationTitle("Photos")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MakeStep.self) { step in
                switch step {
                case .chooseComposition:
                    ChooseCompositionView(session: session)
                case .edit(let style):
                    EditCompositionView(session: session, style: style) {
                        path.append(.preview(style))
                    }
                case .preview(let style):
                    PreviewKeepsakeView(
                        session: session,
                        style: style,
                        onKeepEditing: {
                            if !path.isEmpty { path.removeLast() }
                        },
                        onMakeAnother: {
                            path.removeAll()
                            session.reset()
                        }
                    )
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
