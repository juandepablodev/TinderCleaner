import SwiftUI

struct CardView: View {
  let asset: AssetModel
  let image: UIImage?
  let isTopCard: Bool
  let dragOffset: CGSize

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack(alignment: .top) {
      // Main Card Background & Image
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(uiColor: .systemBackground))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .overlay {
          ZStack(alignment: .bottomTrailing) {
            if let image {
              Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
              Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay {
                  ProgressView()
                    .scaleEffect(1.2)
                }
            }

            if asset.isVideo {
              HStack(spacing: 6) {
                Image(systemName: "play.fill")
                  .font(.subheadline)
                Text(asset.formattedDuration)
                  .font(.subheadline.bold())
              }
              .foregroundStyle(.white)
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(Color.black.opacity(0.75))
              .clipShape(Capsule())
              .padding(12)
            }
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))

      // Intention Badges
      if isTopCard {
        HStack {
          if dragOffset.width > 20 {
            Text("CONSERVAR")
              .font(.title2.bold())
              .foregroundStyle(.green)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color.green, lineWidth: 3)
              )
              .rotationEffect(.degrees(-15))
              .padding(.leading, 20)
              .padding(.top, 24)
              .opacity(min(Double(dragOffset.width) / 100.0, 1.0))
            Spacer()
          } else if dragOffset.width < -20 {
            Spacer()
            Text("ELIMINAR")
              .font(.title2.bold())
              .foregroundStyle(.red)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color.red, lineWidth: 3)
              )
              .rotationEffect(.degrees(15))
              .padding(.trailing, 20)
              .padding(.top, 24)
              .opacity(min(Double(-dragOffset.width) / 100.0, 1.0))
          }
        }
      }
    }
    .rotationEffect(reduceMotion ? .zero : .degrees(Double(dragOffset.width / 20.0)))
    .offset(x: dragOffset.width, y: dragOffset.height)
  }
}
