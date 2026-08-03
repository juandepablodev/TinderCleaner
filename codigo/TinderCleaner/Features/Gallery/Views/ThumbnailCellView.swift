import SwiftUI
import Photos

struct ThumbnailCellView: View {
  let asset: AssetModel
  let viewModel: GalleryViewModel
  let targetSize: CGSize

  @State private var image: UIImage? = nil
  @State private var requestID: PHImageRequestID? = nil

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Rectangle()
        .fill(Color.gray.opacity(0.2))
        .aspectRatio(1, contentMode: .fill)
        .overlay {
          if let image {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
          } else {
            ProgressView()
              .scaleEffect(0.7)
          }
        }
        .clipped()

      if asset.isVideo {
        HStack(spacing: 4) {
          Image(systemName: "play.fill")
            .font(.caption2)
          Text(asset.formattedDuration)
            .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.7))
        .clipShape(Capsule())
        .padding(4)
      }
    }
    .task(id: asset.id) {
      let loadedImage = await viewModel.requestThumbnail(
        for: asset,
        targetSize: targetSize
      ) { reqID in
        Task { @MainActor in
          self.requestID = reqID
        }
      }
      self.image = loadedImage
    }
    .onDisappear {
      if let reqID = requestID {
        viewModel.cancelThumbnailRequest(reqID)
        requestID = nil
      }
    }
  }
}
