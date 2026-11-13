import Flutter
import UIKit

/// One Flutter engine shared by the phone window and the CarPlay scene, so the car screen
/// sees the same live data and can start even if the phone UI was never opened.
let flutterEngine = FlutterEngine(name: "SharedEngine", project: nil, allowHeadlessExecution: true)

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
