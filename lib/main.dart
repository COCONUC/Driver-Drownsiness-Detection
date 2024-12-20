import 'package:driver_drownsiness_detection/tflite_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'bounding_box.dart';
import 'mediapipe_channel.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:async';

final TFLiteService _tfliteService = TFLiteService();
// final CameraService _cameraService = CameraService();
List<CameraDescription> cameras = [];


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Camera
  cameras = await availableCameras();
  // Load TensorFlow Lite model
  await _tfliteService.loadModel();
  // try {
  //   await _cameraService.initialize(); // Initialize the camera
  // } catch (e) {
  //   print("Error initializing camera: $e");
  // }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driver Drowsiness Detection',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: CameraPreviewScreen(),
    );
  }
}

class CameraPreviewScreen extends StatefulWidget {
  @override
  _CameraPreviewScreenState createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isInitialized = false; // Add flag to track initialization
  bool _isCapturing = false; // Add a flag to manage concurrent captures
  String detectionResult = 'No Result';
  String faceDetectionResult = 'No Result';
  Timer? _detectionTimer;
  DateTime? _lastDetectionTime; // Track the last detection time
  bool _isProcessingFrame = false; // Prevent overlapping frame processing
  bool isDetecting = false; // Flag to control detection
  Rect? boundingBox; // Bounding box for the detected face
  int imageWidth = 224; // Default width of the image (update dynamically if needed)
  int imageHeight = 224; // Default height of the image (update dynamically if needed)


  @override
  void initState() {
    super.initState();
    initializeCamera();

    // Find the front camera from the list of available cameras
    // CameraDescription? frontCamera;
    // for (var camera in cameras) {
    //   if (camera.lensDirection == CameraLensDirection.front) {
    //     frontCamera = camera;
    //     break;
    //   }
    // }
    //
    // // Initialize the controller with the front camera
    // if (frontCamera != null) {
    //   _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
    //   _initializeControllerFuture = _controller.initialize();
    // } else {
    //   // Handle case where no front camera is found
    //   print('Front camera not available');
    // }
  }

  // Initialize the front camera
  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => throw Exception("No front camera found!"),
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    setState(() {});
  }

  // Future<void> initializeCamera() async {
  //   final cameras = await availableCameras();
  //   // Select the front camera
  //   final frontCamera = cameras.firstWhere(
  //         (camera) => camera.lensDirection == CameraLensDirection.front,
  //     orElse: () => throw Exception("No front camera found!"),
  //   );
  //   _cameraController = CameraController(
  //       frontCamera,
  //       ResolutionPreset.medium,
  //       enableAudio: false
  //   );
  //   await _cameraController?.initialize();
  //   _isInitialized = true; // Set flag to true after initialization
  //   _cameraController!.startImageStream(processCameraFrame);
  // }

  // Start detection (runs every 3 seconds)
  void startDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("Camera not initialized!");
      return;
    }

    isDetecting = true;

    // Start the image stream
    _cameraController!.startImageStream((CameraImage image) async {
      if (!isDetecting || _isProcessingFrame) return;

      try {
        _isProcessingFrame = true;

        // Preprocess BGRA8888 image
        Uint8List inputBytes = preprocessBGRAImage(
          image.planes[0].bytes,
          image.width,
          image.height,
        );

        processCameraFrame(image);

        // Run inference
        String result = detectDrowsiness(inputBytes);

        // Update UI
        setState(() {
          detectionResult = result;
        });

        print("Detection Result: $result");
      } catch (e) {
        print("Error during detection: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });
  }


  // Stop detection
  void stopDetection() {
    isDetecting = false;
    _detectionTimer?.cancel();

    // Stop the image stream
    _cameraController!.stopImageStream();
    print("Detection Stopped!");
  }

  // Process frames from the camera
  void processCameraFrame(CameraImage image) async {
    print("Processing camera frame...");
    final now = DateTime.now();

    if (_lastDetectionTime != null && DateTime.now().difference(_lastDetectionTime!) < Duration(milliseconds: 3000)) {
      print("Skipping frame: too soon after last detection.");
      return;
    }

    try {
      _isProcessingFrame = true;
      _lastDetectionTime = now;

      // Update image dimensions dynamically
      setState(() {
        imageWidth = image.width;
        imageHeight = image.height;
      });

      print("Image Width: $imageWidth, Image Height: $imageHeight");

      // Use MediaPipe for face detection
      Uint8List bgraBytes = image.planes[0].bytes;
      Rect? detectedBox = await detectFace(bgraBytes);

      if (detectedBox != null) {
        setState(() {
          boundingBox = detectedBox;
          faceDetectionResult = "Face Detected";
        });
        print("Bounding Box Detected: $boundingBox");
      } else {
        setState(() {
          faceDetectionResult = "No Face Detected";
        });
        print("No face detected.");
      }
    } catch (e) {
      print("Error processing frame: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }








  void oldProcessCameraFrame(CameraImage image) async {
    final now = DateTime.now();

    if (_lastDetectionTime != null && now.difference(_lastDetectionTime!) < Duration(seconds: 3)) {
      return;
    }
    if (_isProcessingFrame) return;

    try {
      _isProcessingFrame = true;
      _lastDetectionTime = now;

      // Update image dimensions dynamically
      setState(() {
        imageWidth = image.width;
        imageHeight = image.height;
      });

      // Use MediaPipe for face detection
      Uint8List bgraBytes = image.planes[0].bytes;
      Rect? detectedBox = await detectFace(bgraBytes);

      if (detectedBox != null) {
        setState(() {
          boundingBox = detectedBox;
          faceDetectionResult = "Face Detected";
        });
        print("Bounding Box Detected: $boundingBox");
      } else {
        setState(() {
          boundingBox = null;
          faceDetectionResult = "No Face Detected";
        });
        print("No face detected.");
      }
    } catch (e) {
      print("Error processing frame: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }





  Uint8List convertBGRA8888ToUint8List(CameraImage image) {
    return image.planes[0].bytes; // BGRA8888 is stored in the first plane
  }

  // Preprocess BGRA8888 to 224x224 Float32 Tensor Input
  Uint8List preprocessBGRAImage(Uint8List bgraBytes, int width, int height) {
    // Convert BGRA8888 to RGB
    img.Image rawImage = img.Image.fromBytes(width, height, bgraBytes, format: img.Format.bgra);

    // Resize to 224x224
    img.Image resizedImage = img.copyResize(rawImage, width: 224, height: 224);

    // Normalize and convert to Float32
    List<double> floatList = [];

    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        final pixel = resizedImage.getPixel(x, y);
        floatList.add((img.getRed(pixel) / 255.0));  // Red channel
        floatList.add((img.getGreen(pixel) / 255.0)); // Green channel
        floatList.add((img.getBlue(pixel) / 255.0));  // Blue channel
      }
    }

    // Convert List<double> to Float32List for input tensor
    return Float32List.fromList(floatList).buffer.asUint8List();
  }


  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    // _cameraService.dispose();
    _tfliteService.close();
    super.dispose();
  }

  void updateResult(String result) {
    setState(() {
      detectionResult = result;
    });
  }

  // Run TensorFlow Lite inference
  String detectDrowsiness(Uint8List inputBytes) {
    final result = _tfliteService.runModel(inputBytes);
    double value = result[0];
    return value > 0.5 ? "Drowsy" : "Alert";
  }



  Future<Rect?> detectFace(Uint8List imageBytes) async {
    print("Running face detection...");
    print("Image Width: $imageWidth, Image Height: $imageHeight");
    print("Input Image Bytes Length: ${imageBytes.length}");
    final faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
      enableClassification: true, // Enables "smiling" and "eye open" probability
      enableLandmarks: true, // Enables landmark detection (e.g., eyes, nose, mouth)
      enableTracking: true, // Enables tracking of unique faces
    ));
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      inputImageData: InputImageData(
        size: Size(480, 640), // Ensure it matches Image Width and Height
        imageRotation: InputImageRotation.Rotation_0deg, // Ensure correct rotation
        inputImageFormat: InputImageFormat.BGRA8888,
        planeData: [
          InputImagePlaneMetadata(
            bytesPerRow: 1920, // 480 (width) * 4 (bytes per pixel for BGRA8888)
            height: 640,
            width: 480,
          )
        ],
      ),
    );

    final faces = await faceDetector.processImage(inputImage);
    print("Faces detected: ${faces.length}");

    if (faces.isNotEmpty) {
      for (var face in faces) {
        print("Face bounding box: ${face.boundingBox}");
        print("Smiling probability: ${face.smilingProbability}");
        print("Left eye open probability: ${face.leftEyeOpenProbability}");
        print("Right eye open probability: ${face.rightEyeOpenProbability}");
      }
      return faces.first.boundingBox;
    } else {
      print("No face detected.");
    }
    return null;
  }




  Future<Rect?> oldDetectFace(Uint8List imageBytes) async {
    print("Running face detection...");
    final faceDetector = GoogleMlKit.vision.faceDetector();
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      inputImageData: InputImageData(
        size: Size(224, 224), // Replace with actual image size
        inputImageFormat: InputImageFormat.BGRA8888, // Specify image format
        planeData: [
          InputImagePlaneMetadata(
            bytesPerRow: 224 * 4, // 4 bytes per pixel for BGRA8888
            height: 224,
            width: 224,
          )
        ],
        imageRotation: InputImageRotation.Rotation_0deg, // Corrected enum constant
      ),
    );

    final faces = await faceDetector.processImage(inputImage);

    print("Faces detected: ${faces.length}");

    if (faces.isNotEmpty) {
      final face = faces.first;
      faceDetector.close();
      return face.boundingBox; // Return the bounding box of the detected face
    }

    faceDetector.close();
    return null; // No face detected
  }

  // Function to crop the detected face and preprocess it for TensorFlow Lite
  Uint8List cropAndPreprocessFace(
      Uint8List imageBytes,
      Rect boundingBox,
      int originalWidth,
      int originalHeight,
      ) {
    // Decode the image
    final rawImage = img.decodeImage(imageBytes);

    // Crop the face using bounding box
    final faceCrop = img.copyCrop(
      rawImage!,
      boundingBox.left.toInt(),
      boundingBox.top.toInt(),
      boundingBox.width.toInt(),
      boundingBox.height.toInt(),
    );

    // Resize to model input size (224x224)
    final resizedFace = img.copyResize(faceCrop, width: 224, height: 224);

    // Normalize pixel values to [0, 1]
    List<double> normalizedPixels = [];
    for (var pixel in resizedFace.data) {
      normalizedPixels.add((img.getRed(pixel) / 255.0)); // Red channel
      normalizedPixels.add((img.getGreen(pixel) / 255.0)); // Green channel
      normalizedPixels.add((img.getBlue(pixel) / 255.0)); // Blue channel
    }

    // Convert to Float32List for TensorFlow Lite input
    return Float32List.fromList(normalizedPixels).buffer.asUint8List();
  }






  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Drowsiness Detection'),
      ),
      body:
      Column(
        children: [
          Stack(
            children: [
        if (_cameraController != null && _cameraController!.value.isInitialized)
          CameraPreview(_cameraController!),
        if (boundingBox != null)
          Positioned.fill( // Ensures CustomPaint fills the available space
            child: CustomPaint(
              painter: FaceBoundingBoxPainter(
                boundingBox: boundingBox!,
                imageSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            "Face Detection Result: $faceDetectionResult",
            style: TextStyle(fontSize: 18, color: Colors.black),
          ),
        ),
            ],
    ),
          SizedBox(height: 20),
          // Start/Stop Detection Button
          ElevatedButton(
            onPressed: () {
              if (isDetecting) {
                stopDetection();
              } else {
                startDetection();
              }
              setState(() {}); // Update button text
            },
            child: Text(isDetecting ? "Stop Detection" : "Start Detection"),
          ),
          if (detectionResult.isNotEmpty)
            Container(
              color: detectionResult.contains("Drowsy") ? Colors.red : Colors.green,
              height: 50,
              child: Center(
                child: Text(
                  detectionResult,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: Text(
                "Detection Result: $detectionResult",
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          // ElevatedButton(
          //   onPressed: () async {
          //     try {
          //       Uint8List imageBytes = await _cameraService.captureImage();
          //       print("Image captured successfully!");
          //       String result = detectDrowsiness(imageBytes);
          //       updateResult(result);
          //       // Add code to process or display the image
          //     } catch (e) {
          //     print("Error capturing image: $e");
          //     }
          //     // Capture image and run inference
          //   },
          //   child: Text('Detect Drowsiness'),
          // ),
        ],
      ),
    );
  }

}


