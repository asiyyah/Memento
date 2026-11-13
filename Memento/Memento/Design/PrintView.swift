import SwiftUI

/// A photo shown as a physical print: white border and a soft shadow.
/// Pass `nil` for a blank print. The parent decides the size.
struct PrintView: View {
    var image: UIImage?
    var border: CGFloat = 6

    var body: some View {
        Rectangle()
            .fill(Theme.blankPrint)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .padding(border)
            .background(Color.white)
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

#Preview {
    PrintView(image: nil)
        .frame(width: 180, height: 150)
        .padding(40)
}
