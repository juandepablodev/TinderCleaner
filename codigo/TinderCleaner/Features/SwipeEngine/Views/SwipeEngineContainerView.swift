import SwiftUI

public struct SwipeEngineContainerView: View {
  @State private var viewModel: SwipeEngineViewModel

  public init(assets: [AssetModel], photoService: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
    _viewModel = State(initialValue: SwipeEngineViewModel(assets: assets, photoService: photoService))
  }

  public var body: some View {
    VStack(spacing: 0) {
      // Header Stats
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Remaining")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(viewModel.remainingAssets.count)")
            .font(.headline.bold())
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text("Marked for Deletion")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text("\(viewModel.pendingDeletionCount)")
            .font(.headline.bold())
            .foregroundStyle(.red)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)

      // Main Card Stack Area or Empty Finished State
      if viewModel.remainingAssets.isEmpty {
        ContentUnavailableView {
          Label("Session Completed", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
        } description: {
          Text("You have reviewed all photos in this session.\n\(viewModel.pendingDeletionCount) items marked for deletion.")
        } actions: {
          NavigationLink(destination: SessionSummaryContainerView(session: viewModel.sessionResult)) {
            Text("Ver Resumen")
          }
          .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        CardStackView(viewModel: viewModel)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)

        ActionBarView(
          viewModel: viewModel,
          onKeep: {
            viewModel.processDecision(.keep)
            viewModel.swipeAnimationCompleted()
          },
          onDelete: {
            viewModel.processDecision(.delete)
            viewModel.swipeAnimationCompleted()
          },
          onUndo: {
            viewModel.undoLastDecision()
          }
        )
      }
    }
    .navigationTitle("Review Photos")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        NavigationLink(destination: SessionSummaryContainerView(session: viewModel.sessionResult)) {
          Text("Terminar")
        }
        .disabled(viewModel.historyStack.isEmpty)
      }
    }
  }
}
