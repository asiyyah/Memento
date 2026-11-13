import SwiftUI

/// Stand-in for step 2 (Choose a composition) until the layout engine is built.
struct ChooseCompositionPlaceholder: View {
    let photoCount: Int

    var body: some View {
        VStack(spacing: 8) {
            Text("Compositions come next")
                .font(Theme.Fonts.handwritten(32))
                .foregroundStyle(Theme.ink)
            Text("\(photoCount) photos ready")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
