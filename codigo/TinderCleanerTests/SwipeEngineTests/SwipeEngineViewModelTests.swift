import Testing
import Foundation
import CoreGraphics
import Photos
@testable import TinderCleaner

@Suite struct SwipeEngineViewModelTests {
  @Test func testProcessDecisionAdvancesQueueAndUpdatesHistory() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 10)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService)

    #expect(await viewModel.remainingAssets.count == 10)
    #expect(await viewModel.historyStack.isEmpty)

    await viewModel.processDecision(.keep)
    await viewModel.swipeAnimationCompleted()

    #expect(await viewModel.remainingAssets.count == 9)
    #expect(await viewModel.historyStack.count == 1)
    #expect(await viewModel.historyStack.first?.decision == .keep)
    #expect(await viewModel.historyStack.first?.asset.id == "synthetic-asset-0")
  }

  @Test func testAtomicGuardBlocksOverlappingDecisions() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 10)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService)

    // First call sets swipeInFlight = true
    await viewModel.processDecision(.delete)
    #expect(await viewModel.swipeInFlight == true)

    // Second overlapping call while swipeInFlight is true must be ignored
    await viewModel.processDecision(.keep)

    #expect(await viewModel.historyStack.count == 1)
    #expect(await viewModel.historyStack.first?.decision == .delete)
    #expect(await viewModel.remainingAssets.count == 9)
  }

  @Test func testUndoLastDecisionRestoresAssetToTop() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 5)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService)

    await viewModel.processDecision(.delete)
    await viewModel.swipeAnimationCompleted()

    #expect(await viewModel.pendingDeletionCount == 1)
    #expect(await viewModel.remainingAssets.first?.id == "synthetic-asset-1")

    await viewModel.undoLastDecision()

    #expect(await viewModel.pendingDeletionCount == 0)
    #expect(await viewModel.remainingAssets.first?.id == "synthetic-asset-0")
  }

  @Test func testMemoryInvariantsCountBoundedToThree() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 500)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService)

    for _ in 0..<500 {
      await viewModel.processDecision(.keep)
      await viewModel.swipeAnimationCompleted()
    }

    #expect(await viewModel.imageCache.count <= 3, "imageCache.count must not exceed 3")
    #expect(await viewModel.activeRequests.count <= 3, "activeRequests.count must not exceed 3")
  }

  @Test func testPerformance1000SwipesUnder100ms() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 1000)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService)

    let startTime = Date()
    for _ in 0..<1000 {
      await viewModel.processDecision(.delete)
      await viewModel.swipeAnimationCompleted()
    }
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 0.1, "1,000 swipes must process in < 100 ms")
  }

  @Test func testVelocityEstimatorCalculatesCorrectSpeed() throws {
    var estimator = VelocityEstimator(window: 0.1)
    let startTime = 1000.0

    estimator.add(x: 0, at: startTime)
    estimator.add(x: 60, at: startTime + 0.05) // 60 pt in 0.05 s = 1200 pt/s

    #expect(estimator.horizontalVelocity == 1200.0)
  }
}
