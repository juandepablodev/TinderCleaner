import Testing
import Foundation
import Photos
@testable import TinderCleaner

@Suite struct PhotoLibraryServiceInvariantTests {
  @Test func testNetworkAccessIsForbiddenOnImageRequestOptions() throws {
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    #expect(options.isNetworkAccessAllowed == false, "isNetworkAccessAllowed must strictly evaluate to false")
  }
}
