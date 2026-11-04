import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var isSecureWindowEnabled = false
  private var privacyCoverView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "screen_protector", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] (call, channelResult) in
        if call.method == "enableSecure" {
          self?.isSecureWindowEnabled = true
          channelResult(nil)
        } else if call.method == "disableSecure" {
          self?.isSecureWindowEnabled = false
          channelResult(nil)
        } else {
          channelResult(FlutterMethodNotImplemented)
        }
      }
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    if isSecureWindowEnabled, let window = self.window {
      if privacyCoverView == nil {
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = window.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.tag = 9999
        window.addSubview(blurView)
        privacyCoverView = blurView
      }
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    privacyCoverView?.removeFromSuperview()
    window?.viewWithTag(9999)?.removeFromSuperview()
    privacyCoverView = nil
  }
}
