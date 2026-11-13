// Bridge from Flutter to the widget and the drive Live Activity ("mzd/car_widgets" channel).
import ActivityKit
import Flutter
import WidgetKit

enum CarWidgets {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mzd/car_widgets", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "updateStatus":
        updateStatus(args)
        result(nil)
      case "startDrive":
        startDrive(args)
        result(nil)
      case "updateDrive":
        updateDrive(args)
        result(nil)
      case "endDrive":
        endDrive()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func num(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue }

  static func updateStatus(_ a: [String: Any]) {
    MzdStatus(
      carName: a["carName"] as? String ?? "Mi Mazda",
      connected: a["connected"] as? Bool ?? false,
      coolant: num(a["coolant"]),
      voltage: num(a["voltage"]),
      fuel: num(a["fuel"]),
      serviceTitle: a["serviceTitle"] as? String,
      serviceLabel: a["serviceLabel"] as? String,
      serviceLevel: a["serviceLevel"] as? String,
      dtcCount: (a["dtcCount"] as? NSNumber)?.intValue,
      updated: Date()
    ).save()
    WidgetCenter.shared.reloadTimelines(ofKind: "MiMazdaStatus")
  }

  private static func state(_ a: [String: Any]) -> MzdDriveAttributes.ContentState {
    MzdDriveAttributes.ContentState(
      speed: num(a["speed"]), rpm: num(a["rpm"]), coolant: num(a["coolant"]), voltage: num(a["voltage"]),
      warning: a["warning"] as? String)
  }

  private static var current: Activity<MzdDriveAttributes>? {
    Activity<MzdDriveAttributes>.activities.first
  }

  static func startDrive(_ a: [String: Any]) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    if current != nil { return updateDrive(a) }
    let attributes = MzdDriveAttributes(carName: a["carName"] as? String ?? "Mi Mazda")
    _ = try? Activity.request(
      attributes: attributes,
      content: ActivityContent(state: state(a), staleDate: Date().addingTimeInterval(120)),
      pushType: nil)
  }

  static func updateDrive(_ a: [String: Any]) {
    guard let activity = current else { return startDrive(a) }
    let content = ActivityContent(state: state(a), staleDate: Date().addingTimeInterval(120))
    Task { await activity.update(content) }
  }

  static func endDrive() {
    for activity in Activity<MzdDriveAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
