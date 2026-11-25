import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Shared with SceneDelegate so plugins registered here are the ones the
  // visible FlutterViewController actually runs against.
  lazy var flutterEngine = FlutterEngine(name: "main engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// iOS 27 terminates apps that declare no UIKit scene lifecycle adoption at
// all; this opts back into the single-window behavior Flutter's classic
// AppDelegate-only setup already provides, reusing AppDelegate's engine
// instead of FlutterSceneDelegate's default of spinning up its own.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene,
          let appDelegate = UIApplication.shared.delegate as? AppDelegate
    else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(
      engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
    self.window = window
    window.makeKeyAndVisible()
  }
}
