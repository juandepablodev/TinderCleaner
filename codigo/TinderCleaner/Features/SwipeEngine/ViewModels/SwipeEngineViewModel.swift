import Foundation
import Photos
import UIKit
import SwiftUI
import AVFoundation

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

  // Bounded image & video cache and active requests (Invariants: count <= 3)
  var imageCache: [String: UIImage] = [:]
  var playerItemCache: [String: AVPlayerItem] = [:]
  var activeRequests: [String: PHImageRequestID] = [:]

  private let photoService: PhotoLibraryServiceProtocol
  private let persistenceService: SessionPersistenceServiceProtocol
  public var displayTargetSize: CGSize = CGSize(width: 600, height: 800)

  public init(
    assets: [AssetModel],
    photoService: PhotoLibraryServiceProtocol,
    persistenceService: SessionPersistenceServiceProtocol = SessionPersistenceService()
  ) {
    self.remainingAssets = assets
    self.photoService = photoService
    self.persistenceService = persistenceService
    preloadWindow()
  }

  public init(
    restoringSavedState state: SavedSessionState,
    allAssets: [AssetModel],
    photoService: PhotoLibraryServiceProtocol,
    persistenceService: SessionPersistenceServiceProtocol = SessionPersistenceService()
  ) {
    let assetMap = Dictionary(uniqueKeysWithValues: allAssets.map { ($0.id, $0) })
    
    self.historyStack = state.classifiedAssets.compactMap { saved in
      guard let asset = assetMap[saved.assetID] else { return nil }
      return ClassifiedAsset(asset: asset, decision: saved.decision, timestamp: saved.timestamp)
    }
    
    self.remainingAssets = state.remainingAssetIDs.compactMap { assetMap[$0] }
    self.photoService = photoService
    self.persistenceService = persistenceService
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
    persistCurrentState()
  }

  public func swipeAnimationCompleted() {
    swipeInFlight = false
  }

  public func undoLastDecision() {
    guard !swipeInFlight, let last = historyStack.popLast() else { return }
    remainingAssets.insert(last.asset, at: 0)
    preloadWindow()
    persistCurrentState()
  }

  private func persistCurrentState() {
    let savedClassified = historyStack.map {
      SavedClassifiedAsset(assetID: $0.asset.id, decision: $0.decision, timestamp: $0.timestamp)
    }
    let remainingIDs = remainingAssets.map(\.id)
    let state = SavedSessionState(lastModified: Date(), classifiedAssets: savedClassified, remainingAssetIDs: remainingIDs)
    persistenceService.saveSession(state)
  }

  public func image(for asset: AssetModel) -> UIImage? {
    imageCache[asset.id]
  }

  public func playerItem(for asset: AssetModel) -> AVPlayerItem? {
    playerItemCache[asset.id]
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
    playerItemCache.removeValue(forKey: asset.id)
  }

  public func preloadWindow() {
    let window = Array(remainingAssets.prefix(5))
    let wantedIDs = Set(window.map(\.id))

    // Cancel requests for assets that fell out of the prefetch window
    let currentActiveKeys = Array(activeRequests.keys)
    for id in currentActiveKeys where !wantedIDs.contains(id) {
      if let reqID = activeRequests.removeValue(forKey: id) {
        photoService.cancelImageRequest(reqID)
      }
      imageCache.removeValue(forKey: id)
      playerItemCache.removeValue(forKey: id)
    }

    // Request thumbnails/video items for missing items in the window
    for asset in window where imageCache[asset.id] == nil && activeRequests[asset.id] == nil {
      let assetID = asset.id
      let size = displayTargetSize
      
      // Mark as active synchronously to prevent duplicate Tasks while waiting for the real ID
      activeRequests[assetID] = PHInvalidImageRequestID
      
      Task { @MainActor [weak self, photoService] in
        guard let self else { return }
        let image = await photoService.requestThumbnail(
          for: asset,
          targetSize: size,
          onRequestID: { [weak self] requestID in
            guard let self else { return }
            Task { @MainActor [self] in
              if self.activeRequests[assetID] != nil {
                self.activeRequests[assetID] = requestID
              } else {
                self.photoService.cancelImageRequest(requestID)
              }
            }
          }
        )
        
        let wasActive = self.activeRequests[assetID] != nil
        self.activeRequests.removeValue(forKey: assetID)
        if wasActive, let image {
          self.imageCache[assetID] = image
        }

        // If it's a video asset, also request the AVPlayerItem for video playback
        if wasActive && asset.isVideo && self.playerItemCache[assetID] == nil {
          let item = await photoService.requestPlayerItem(
            for: asset,
            onRequestID: { _ in }
          )
          if let item {
            self.playerItemCache[assetID] = item
          }
        }
      }
    }
  }
}
