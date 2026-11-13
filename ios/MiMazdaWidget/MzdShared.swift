// Shared between the Runner app and the MiMazdaWidget extension (member of both targets).
import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

enum MzdShared {
  static let appGroup = "group.com.jeronimotech.mzdOwner"
  static let statusKey = "mzd.status"
}

/// Snapshot written by the app and read by the "Estado de Mi Mazda" widget.
struct MzdStatus: Codable {
  var carName: String
  var connected: Bool
  var coolant: Double?
  var voltage: Double?
  var fuel: Double?
  var serviceTitle: String?
  var serviceLabel: String?
  /// "due" | "soon" | "ok" | "unknown"
  var serviceLevel: String?
  var dtcCount: Int?
  var updated: Date

  static let placeholder = MzdStatus(
    carName: "Mi Mazda", connected: true, coolant: 90, voltage: 14.2, fuel: 64,
    serviceTitle: "Aceite y filtro", serviceLabel: "En 1.200 km", serviceLevel: "soon",
    dtcCount: 0, updated: Date())

  static func load() -> MzdStatus? {
    guard let data = UserDefaults(suiteName: MzdShared.appGroup)?.data(forKey: MzdShared.statusKey) else { return nil }
    return try? JSONDecoder().decode(MzdStatus.self, from: data)
  }

  func save() {
    guard let data = try? JSONEncoder().encode(self) else { return }
    UserDefaults(suiteName: MzdShared.appGroup)?.set(data, forKey: MzdShared.statusKey)
  }
}

#if canImport(ActivityKit)
/// Live Activity shown while driving (lock screen, Dynamic Island and CarPlay on iOS 26).
@available(iOS 16.1, *)
struct MzdDriveAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var speed: Double?
    var rpm: Double?
    var coolant: Double?
    var voltage: Double?
    /// Short warning, e.g. "Motor caliente" — nil when everything is fine.
    var warning: String?
  }

  var carName: String
}
#endif
