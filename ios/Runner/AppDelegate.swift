import UIKit
import Flutter

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    var drowsinessDetector: DrowsinessDetector?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let detectionChannel = FlutterMethodChannel(name: "com.yourapp/face_detection", binaryMessenger: controller.binaryMessenger)
        
        drowsinessDetector = DrowsinessDetector()
        
        detectionChannel.setMethodCallHandler { (call, result) in
            guard call.method == "detectDrowsiness" else {
                result(FlutterMethodNotImplemented)
                return
            }
            
            guard let args = call.arguments as? [String: Any],
                  let imageData = args["image"] as? FlutterStandardTypedData,
                  let uiImage = UIImage(data: imageData.data) else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "No valid image data", details: nil))
                return
            }
            
            self.drowsinessDetector?.detectFace(in: uiImage) { isDrowsy in
                result(isDrowsy)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
