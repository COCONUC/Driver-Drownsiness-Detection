import Flutter
import UIKit
import MLKitFaceDetection
import MLKitVision


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
    
    private func detectFaceWithMediaPipe(result: @escaping FlutterResult) {
        // Set up the face detector options
        let options = FaceDetectorOptions()
        options.performanceMode = .fast
        options.landmarkMode = .all
        options.classificationMode = .all

        let faceDetector = FaceDetector.faceDetector(options: options)

        // Use a sample image here - replace with the actual image from the camera
        let visionImage = VisionImage(image: UIImage(named: "sample.jpg")!)
        faceDetector.process(visionImage) { faces, error in
          guard error == nil, let faces = faces, !faces.isEmpty else {
            result("No face detected")
            return
          }

          // Extract facial landmarks or attributes for drowsiness detection
          if let face = faces.first {
            let leftEyeOpenProbability = face.leftEyeOpenProbability
            let rightEyeOpenProbability = face.rightEyeOpenProbability

            if leftEyeOpenProbability < 0.5 && rightEyeOpenProbability < 0.5 {
              result("Drowsiness detected")
            } else {
              result("Driver is alert")
            }
          }
        }
      }
    
}
