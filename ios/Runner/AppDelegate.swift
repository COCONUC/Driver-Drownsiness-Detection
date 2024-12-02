import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let mediaPipeChannel = FlutterMethodChannel(name: "com.example.driver_drowsiness_detection/mediapipe",
                                                binaryMessenger: controller.binaryMessenger)

    mediaPipeChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "processImage" {
        // TODO: Add MediaPipe processing logic here
        result("Image processed successfully")
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
