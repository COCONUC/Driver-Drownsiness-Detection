import 'package:driver_drownsiness_detection/tflite_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'bounding_box.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

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
  DateTime? _lastFaceDetectionTime; // Track the last detection time
  bool _isProcessingFrame = false; // Prevent overlapping frame processing
  bool _isProcessingFace = false; // Prevent overlapping frame processing
  bool isDetecting = false; // Flag to control detection
  Rect? boundingBox; // Bounding box for the detected face
  bool showBoundingBox = false; // Default to showing the bounding box
  int imageWidth = 224; // Default width of the image (update dynamically if needed)
  int imageHeight = 224; // Default height of the image (update dynamically if needed)
  final AudioPlayer audioPlayer = AudioPlayer(); // Initialize audio player
  int drowsyCount = 0; // Counter for consecutive drowsy detections



  @override
  void initState() {
    super.initState();
    initializeCamera();
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
        String result = await detectDrowsiness(inputBytes);

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
    // print("Detection Stopped!");
  }

  // Process frames from the camera
  void processCameraFrame(CameraImage image) async {
    // print("Processing camera frame...");
    final now = DateTime.now();

    if (_lastFaceDetectionTime != null && DateTime.now().difference(_lastFaceDetectionTime!) < Duration(milliseconds: 500)) {
      // print("Skipping frame: too soon after last detection.");
      return;
    }

    try {
      _isProcessingFace = true;
      _lastFaceDetectionTime = now;

      // Update image dimensions dynamically
      setState(() {
        imageWidth = image.width;
        imageHeight = image.height;
      });

      // print("Image Width: $imageWidth, Image Height: $imageHeight");

      // Use MediaPipe for face detection
      Uint8List bgraBytes = image.planes[0].bytes;
      Rect? detectedBox = await detectFace(bgraBytes);

      if (detectedBox != null) {
        setState(() {
          boundingBox = detectedBox;
          faceDetectionResult = "Face Detected";
        });
        // print("Bounding Box Detected: $boundingBox");
      } else {
        setState(() {
          faceDetectionResult = "No Face Detected";
        });
        // print("No face detected.");
      }
    } catch (e) {
      print("Error processing frame: $e");
    } finally {
      _isProcessingFace = false;
    }
  }



  // Run TensorFlow Lite inference
  String olddetectDrowsiness(Uint8List inputBytes) {
    // final now = DateTime.now();
    //
    // if (_lastDetectionTime != null) {
    //   final timeInterval = now.difference(_lastDetectionTime!).inMilliseconds / 5000.0;
    //   print("Time interval since last detection: ${timeInterval.toStringAsFixed(2)} seconds");
    //
    //   if (timeInterval < 1.0) {
    //     print("Skipping detection: Too soon since last detection.");
    //     return "Skipping";
    //   }
    // }
    //
    // _lastDetectionTime = now;

    final result = _tfliteService.runModel(inputBytes);
    double value = result[0];
    return value > 0.5 ? "Drowsy" : "Alert";
  }

  Future<String> detectDrowsiness(Uint8List inputBytes) async {
    try {
      // Limit detections to every 1 seconds
      final now = DateTime.now();
      if (_lastDetectionTime != null) {
        final timeInterval = now.difference(_lastDetectionTime!).inMilliseconds / 1000.0;

        if (timeInterval < 1.0) { // Check against the correct interval
          // print("Skipping detection: Too soon since last detection.");
          return detectionResult;
        }
      }


      _lastDetectionTime = now; // Update the last detection time

      final result = _tfliteService.runModel(inputBytes); // Ensure result matches the updated runModel
      if (result[0] == "Error") {
        print("Error running model");
        return " ";
      }
      double value = result[0];

      // Add threshold logic for binary classification
      if (value >= 0.5) {
        drowsyCount++;
        print("Drowsy count: $drowsyCount");

        if (drowsyCount >= 4) {
          // Play sound alert after 4 consecutive drowsy detections
          await audioPlayer.play(AssetSource('sounds/warning.mp3'));
          drowsyCount = 0; // Reset counter after alert
        }
        return "Drowsy"; // Class 1
      } else {
        drowsyCount = 0; // Reset counter if not drowsy
        return "Alert"; // Class 0
      }
    } catch (e) {
      print("Error detecting drowsiness: $e");
      return "Error";
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

    // Debug log: Print first 10 normalized values
    print("Preprocessed input data (first 10 values): ${floatList.take(10).toList()}");

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



  Future<Rect?> detectFace(Uint8List imageBytes) async {
    print("Running face detection...");
    // print("Image Width: $imageWidth, Image Height: $imageHeight");
    // print("Input Image Bytes Length: ${imageBytes.length}");
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
      return faces.first.boundingBox;
    } else {
      print("No face detected.");
    }
    return null;
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
        if (showBoundingBox && boundingBox != null)
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
          ElevatedButton(
            onPressed: () {
              setState(() {
                showBoundingBox = !showBoundingBox; // Toggle visibility
              });
            },
            child: Text(showBoundingBox ? "Hide Bounding Box" : "Show Bounding Box"),
          ),
          SizedBox(height: 10),
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


