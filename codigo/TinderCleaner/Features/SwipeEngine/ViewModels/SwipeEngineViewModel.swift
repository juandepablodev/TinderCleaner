import Foundation
import Photos
import UIKit
import SwiftUI

@Observable
@MainActor
public final class SwipeEngineViewModel {
  public private(set) var remainingAssets: [AssetModel] = []
  public private(set) var historyStack: [ClassifiedAsset] = []
  public private(set) var swipeInFlight: Bool = false

  private static let historyLimit = 200

  public var currentAsset: AssetModel? { remainingAssets.first }
  public var nextAsset: AssetModel? { remainingAssets.dropFirst().first }
  public var pendingDeletionCount: Int { historyStack.filter { $0.decision == .delete }.count }
  public var keepCount: Int { historyStack.filter { $0.decision == .keep }.count }

  public var sessionResult: SessionResult {
    let keep = historyStack.filter { $0.decision == .keep }.map(\.asset)
    let delete = historyStack.filter { $0.decision == .delete }.map(\.asset)
    return SessionResult(keep: keep, pendingDeletion: delete)
  }

  // Bounded image cache and active requests (Invariants: count <= 3)
  var imageCache: [String: UIImage] = [:]
  var activeRequests: [String: PHImageRequestID] = [:]

  private let photoService: PhotoLibraryServiceProtocol
  public var displayTargetSize: CGSize = CGSize(width: 600, height: 800)

  public init(assets: [AssetModel], photoService: PhotoLibraryServiceProtocol) {
    self.remainingAssets = assets
    self.photoService = photoService
    preloadWindow()
  }

  /// Atomic classification method. Ignores overlapping calls while a swipe animation is in flight.
  public func processDecision(_ decision: SwipeDecision) {
    guard !swipeInFlight, let asset = remainingAssets.first else { return }
    swipeInFlight = true

    historyStack.append(ClassifiedAsset(asset: asset, decision: decision, timestamp: Date()))
    if historyStack.count > Self.historyLimit {
      historyStack.removeFirst()
    }

    releaseResources(for: asset)
    remainingAssets.removeFirst()
    preloadWindow()
  }

  public func swipeAnimationCompleted() {
    swipeInFlight = false
  }

  public func undoLastDecision() {
    guard !swipeInFlight, let last = historyStack.popLast() else { return }
    remainingAssets.insert(last.asset, at: 0)
    preloadWindow()
  }

  public func image(for asset: AssetModel) -> UIImage? {
    imageCache[asset.id]
  }

  public func updateDisplayTargetSize(_ size: CGSize) {
    guard size.width > 0, size.height > 0, size != displayTargetSize else { return }
    self.displayTargetSize = size
    preloadWindow()
  }

  // MARK: - Private Memory & Preload Management

  private func releaseResources(for asset: AssetModel) {
    if let requestID = activeRequests.removeValue(forKey: asset.id) {
      photoService.cancelImageRequest(requestID)
    }
    imageCache.removeValue(forKey: asset.id)
  }

  public func preloadWindow() {
    let window = Array(remainingAssets.prefix(3))
    let wantedIDs = Set(window.map(\.id))

    // Cancel requests for assets that fell out of the prefetch window
    let currentActiveKeys = Array(activeRequests.keys)
    for id in currentActiveKeys where !wantedIDs.contains(id) {
      if let reqID = activeRequests.removeValue(forKey: id) {
        photoService.cancelImageRequest(reqID)
      }
      imageCache.removeValue(forKey: id)
    }

    // Request thumbnails for missing items in the window
    for asset in window where imageCache[asset.id] == nil && activeRequests[asset.id] == nil {
      let assetID = asset.id
      let size = displayTargetSize
      Task { [weak self, photoService] in
        let image = await photoService.requestThumbnail(
          for: asset,
          targetSize: size,
          onRequestID: { requestID in
            Task { @MainActor [weak self] in
              self?.activeRequests[assetID] = requestID
            }
          }
        )
        
        await MainActor.run { [weak self] in
          guard let self else { return }
          self.activeRequests.removeValue(forKey: assetID)
          if let image {
            self.imageCache[assetID] = image
          }
        }
      }
    }
  }
}
