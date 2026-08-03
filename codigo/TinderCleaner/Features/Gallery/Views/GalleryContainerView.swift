import SwiftUI

public struct GalleryContainerView: View {
  @State private var viewModel: GalleryViewModel
  @State private var showLimitedPicker: Bool = false

  public init(photoService: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
    _viewModel = State(initialValue: GalleryViewModel(photoService: photoService))
  }

  public var body: some View {
    NavigationStack {
      Group {
        switch viewModel.authorizationStatus {
        case .notDetermined:
          NotDeterminedPermissionView {
            Task {
              await viewModel.checkAndRequestPermission()
            }
          }

        case .authorized:
          GalleryGridView(viewModel: viewModel)

        case .limited:
          VStack(spacing: 0) {
            HStack {
              Label("Limited Access", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.bold())
                .foregroundStyle(.orange)
              Spacer()
              Button("Manage") {
                showLimitedPicker = true
              }
              .font(.footnote.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))

            GalleryGridView(viewModel: viewModel)
          }
          .sheet(isPresented: $showLimitedPicker) {
            LimitedLibraryPickerRepresentable()
          }

        case .denied, .restricted:
          PermissionDeniedView()

        @unknown default:
          PermissionDeniedView()
        }
      }
      .navigationTitle("Gallery")
      .task {
        await viewModel.checkAndRequestPermission()
      }
    }
  }
}
