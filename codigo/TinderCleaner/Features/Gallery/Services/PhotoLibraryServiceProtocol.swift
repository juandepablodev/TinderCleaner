import Foundation
import Photos
import UIKit

/// Protocol for interacting with PhotoKit, enforcing Sendable concurrency and dependency injection.
public protocol PhotoLibraryServiceProtocol: Sendable {
  var authorizationStatus: PHAuthorizationStatus { get }
  func requestAuthorization() async -> PHAuthorizationStatus
  func fetchAssetCount() async -> Int
  func fetchAssets(in range: Range<Int>) async -> [AssetModel]
  
  func requestThumbnail(
    for asset: AssetModel,
    targetSize: CGSize,
    onRequestID: @Sendable (PHImageRequestID) -> Void
  ) async -> UIImage?
  
  func cancelImageRequest(_ requestID: PHImageRequestID)
  func startCaching(for assets: [AssetModel], targetSize: CGSize)
  func stopCaching(for assets: [AssetModel], targetSize: CGSize)
  func changeStream() -> AsyncStream<AssetLibraryChange>
}
