import Flutter
import UIKit

/// Phone window: attaches to the shared engine (the CarPlay scene is handled by
/// flutter_carplay.FlutterCarPlaySceneDelegate, declared in Info.plist).
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let phoneWindow = UIWindow(windowScene: windowScene)
    let controller = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
    controller.loadDefaultSplashScreenView()
    phoneWindow.rootViewController = controller
    window = phoneWindow
    phoneWindow.makeKeyAndVisible()
  }
}
