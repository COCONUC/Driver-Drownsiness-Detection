import UIKit
import Flutter
import MLKitFaceDetection
import MLKitVision

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
 override func application(
   _ application: UIApplication,
   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
 ) -> Bool {
   let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
   let mediaPipeChannel = FlutterMethodChannel(name: "com.example.driver_drowsiness_detection/mediapipe",
                                               binaryMessenger: controller.binaryMessenger)

   mediaPipeChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
     if call.method == "processImageWithPath" {
       if let args = call.arguments as? [String: Any],
          let imagePath = args["imagePath"] as? String {
         self.detectFaceWithMediaPipe(imagePath: imagePath, result: result)
       } else {
         result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path missing", details: nil))
       }
     } else {
       result(FlutterMethodNotImplemented)
     }
   }

   GeneratedPluginRegistrant.register(with: self)
   return super.application(application, didFinishLaunchingWithOptions: launchOptions)
 }

 private func detectFaceWithMediaPipe(imagePath: String, result: @escaping FlutterResult) {
   guard let image = UIImage(contentsOfFile: imagePath) else {
     print("Failed to load image from path: \(imagePath)")
     result("Failed to load image")
     return
   }
     // Log image size for debugging
     print("Image size: \(image.size.width) x \(image.size.height)")

   let visionImage = VisionImage(image: image)
     visionImage.orientation = image.imageOrientation // Set orientation explicitly
   let options = FaceDetectorOptions()
   options.performanceMode = .accurate
   options.landmarkMode = .all
   options.classificationMode = .all
     options.minFaceSize = 0.1 // Detect smaller faces if necessary


   let faceDetector = FaceDetector.faceDetector(options: options)

   faceDetector.process(visionImage) { faces, error in
     if let error = error {
       print("Face detection error: \(error.localizedDescription)")
       result("Face detection error: \(error.localizedDescription)")
       return
     }

     guard let faces = faces, !faces.isEmpty else {
       print("No faces detected")
       result("No faces detected")
       return
     }

     if let face = faces.first {
       let leftEyeOpenProbability = face.leftEyeOpenProbability
       let rightEyeOpenProbability = face.rightEyeOpenProbability

       print("Left Eye Open Probability: \(leftEyeOpenProbability)")
       print("Right Eye Open Probability: \(rightEyeOpenProbability)")

       if leftEyeOpenProbability < 0.5 && rightEyeOpenProbability < 0.5 {
         print("Drowsiness detected")
         result("Drowsiness detected")
       } else {
         print("Driver is alert")
         result("Driver is alert")
       }
     } else {
       print("No face detected")
       result("No face detected")
     }
   }
 }
}
