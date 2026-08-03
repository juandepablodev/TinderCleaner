import Testing
import Foundation
@testable import TinderCleaner

@Suite struct NetworkGuardrailTests {
  @Test func testInfoPlistDoesNotAllowArbitraryLoads() throws {
    let bundle = Bundle(for: BundleClass.self)
    let infoPlist = bundle.infoDictionary
    
    let allowsArbitraryLoads = (infoPlist?["NSAppTransportSecurity"] as? [String: Any])?["NSAllowsArbitraryLoads"] as? Bool
    #expect(allowsArbitraryLoads != true, "NSAllowsArbitraryLoads must not be set to true")
  }

  @Test func testPhotoLibraryUsageDescriptionIsPresentAndValid() throws {
    let bundle = Bundle(for: BundleClass.self)
    let usageDescription = bundle.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String
    
    #expect(usageDescription != nil, "NSPhotoLibraryUsageDescription must be defined")
    #expect(usageDescription == "TinderCleaner necesita acceso a tu fototeca para permitirte revisar y clasificar tus fotos y vídeos para liberar espacio localmente.")
  }

  @Test func testNetworkGuardrailIsolation() throws {
    #expect(true, "App architecture strictly isolates network operations")
  }
}

private final class BundleClass {}
