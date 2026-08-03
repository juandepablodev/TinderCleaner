import Foundation
import Photos
import UIKit

/// Production implementation of PhotoLibraryServiceProtocol interfacing with PhotoKit.
public final class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol, @unchecked Sendable {
  private let imageManager: PHCachingImageManager
  private let photoLibrary: PHPhotoLibrary
  private var fetchResult: PHFetchResult<PHAsset>?
  private var continuation: AsyncStream<AssetLibraryChange>.Continuation?

  public init(
    imageManager: PHCachingImageManager = PHCachingImageManager(),
    photoLibrary: PHPhotoLibrary = .shared()
  ) {
    self.imageManager = imageManager
    self.photoLibrary = photoLibrary
    super.init()
    self.photoLibrary.register(self)
  }

  deinit {
    photoLibrary.unregisterChangeObserver(self)
  }

  public var authorizationStatus: PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus(for: .readWrite)
  }

  public func requestAuthorization() async -> PHAuthorizationStatus {
    await PHPhotoLibrary.requestAuthorization(for: .readWrite)
  }

  public func fetchAssetCount() async -> Int {
    let result = getOrFetchResult()
    return result.count
  }

  public func fetchAssets(in range: Range<Int>) async -> [AssetModel] {
    let result = getOrFetchResult()
    guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= result.count else {
      return []
    }
    
    var assets: [AssetModel] = []
    assets.reserveCapacity(range.count)
    
    for index in range {
      let phAsset = result.object(at: index)
      assets.append(phAsset.toAssetModel())
    }
    
    return assets
  }

  public func requestThumbnail(
    for asset: AssetModel,
    targetSize: CGSize,
    onRequestID: @Sendable (PHImageRequestID) -> Void
  ) async -> UIImage? {
    let result = getOrFetchResult()
    guard let phAsset = fetchPHAsset(with: asset.id, in: result) else {
      return nil
    }

    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false // Privacy invariant: local-only access
    options.deliveryMode = .opportunistic
    options.resizeMode = .fast
    options.isSynchronous = false

    var currentRequestID: PHImageRequestID?

    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        let reqID = imageManager.requestImage(
          for: phAsset,
          targetSize: targetSize,
          contentMode: .aspectFill,
          options: options
        ) { image, info in
          let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
          if !isDegraded || image != nil {
            continuation.resume(returning: image)
          }
        }
        currentRequestID = reqID
        onRequestID(reqID)
      }
    } onCancel: {
      if let reqID = currentRequestID {
        imageManager.cancelImageRequest(reqID)
      }
    }
  }

  public func cancelImageRequest(_ requestID: PHImageRequestID) {
    imageManager.cancelImageRequest(requestID)
  }

  public func startCaching(for assets: [AssetModel], targetSize: CGSize) {
    let phAssets = resolvePHAssets(for: assets)
    guard !phAssets.isEmpty else { return }
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    imageManager.startCachingImages(for: phAssets, targetSize: targetSize, contentMode: .aspectFill, options: options)
  }

  public func stopCaching(for assets: [AssetModel], targetSize: CGSize) {
    let phAssets = resolvePHAssets(for: assets)
    guard !phAssets.isEmpty else { return }
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    imageManager.stopCachingImages(for: phAssets, targetSize: targetSize, contentMode: .aspectFill, options: options)
  }

  public func changeStream() -> AsyncStream<AssetLibraryChange> {
    AsyncStream { continuation in
      self.continuation = continuation
    }
  }

  // MARK: - Private Helpers

  private func getOrFetchResult() -> PHFetchResult<PHAsset> {
    if let result = fetchResult {
      return result
    }
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    let result = PHAsset.fetchAssets(with: fetchOptions)
    self.fetchResult = result
    return result
  }

  private func fetchPHAsset(with id: String, in result: PHFetchResult<PHAsset>) -> PHAsset? {
    let options = PHFetchOptions()
    return PHAsset.fetchAssets(withLocalIdentifiers: [id], options: options).firstObject
  }

  private func resolvePHAssets(for assets: [AssetModel]) -> [PHAsset] {
    let identifiers = assets.map(\.id)
    guard !identifiers.isEmpty else { return [] }
    let options = PHFetchOptions()
    let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)
    var phAssets: [PHAsset] = []
    result.enumerateObjects { asset, _, _ in
      phAssets.append(asset)
    }
    return phAssets
  }
}

extension PhotoLibraryService: PHPhotoLibraryChangeObserver {
  public func photoLibraryDidChange(_ changeInstance: PHChange) {
    guard let currentResult = fetchResult,
          let details = changeInstance.changeDetails(for: currentResult) else {
      return
    }

    self.fetchResult = details.fetchResultAfterChanges
    
    var snapshot: [AssetModel] = []
    snapshot.reserveCapacity(details.fetchResultAfterChanges.count)
    details.fetchResultAfterChanges.enumerateObjects { asset, _, _ in
      snapshot.append(asset.toAssetModel())
    }

    let change = AssetLibraryChange(
      inserted: details.insertedIndexes ?? IndexSet(),
      removed: details.removedIndexes ?? IndexSet(),
      changed: details.changedIndexes ?? IndexSet(),
      snapshotAfter: snapshot,
      hasIncrementalChanges: details.hasIncrementalChanges
    )

    continuation?.yield(change)
  }
}

private extension PHAsset {
  func toAssetModel() -> AssetModel {
    AssetModel(
      id: localIdentifier,
      mediaType: mediaType,
      duration: duration,
      creationDate: creationDate,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight
    )
  }
}
