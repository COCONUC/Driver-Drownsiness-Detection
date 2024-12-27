import 'package:driver_drownsiness_detection/tflite_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
  Offset? leftEyePosition;   // Detected left eye position
  Offset? rightEyePosition;  // Detected right eye position
  int imageWidth = 480; // Default width of the image (update dynamically if needed)
  int imageHeight = 640; // Default height of the image (update dynamically if needed)
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
        // Uint8List inputBytes = preprocessBGRAImage(
        //   image.planes[0].bytes,
        //   image.width,
        //   image.height,
        // );

        // processCameraFrame(image);

        final face =  await detectFaceAndCrop(image.planes[0].bytes);

        if(face != null) {
          // print("Running drowsiness model...");
          final Rect detectBoundingBox = face['boundingBox'];
          final Uint8List preprocessedFace = preprocessFace(face['croppedFace']);
          // print("Face image size: ${preprocessedFace.length}");

          setState(() {
            boundingBox = detectBoundingBox;
            faceDetectionResult = "Face Detected";
          });
          // Run inference
          String result = await detectDrowsiness(preprocessedFace);

          // Update UI
          setState(() {
            detectionResult = result;
          });
          print("Detection Result: $result");
        } else {
          setState(() {
            boundingBox = null;
            faceDetectionResult = "No Face Detected";
          });
          print("No face found in the image.");
        }
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
      final detectedBox = await detectFaceAndCrop(bgraBytes);

      if (detectedBox != null) {
        final Rect detectedFaceBox = detectedBox['boundingBox'];
        setState(() {
          boundingBox = detectedFaceBox;
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


  Uint8List convertBGRAtoJPG(Uint8List bgraBytes, int width, int height) {
    // Create an empty RGB image
    final img.Image rgbImage = img.Image(width, height);

    int index = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // BGRA8888 to RGB888
        int b = bgraBytes[index];
        int g = bgraBytes[index + 1];
        int r = bgraBytes[index + 2];
        // Ignore alpha channel
        rgbImage.setPixel(x, y, img.getColor(r, g, b));
        index += 4; // Move to the next pixel
      }
    }

    // Encode the RGB image as JPG
    return Uint8List.fromList(img.encodeJpg(rgbImage));
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
    // print("Preprocessed input data (first 10 values): ${floatList.take(10).toList()}");

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
    // print("Running face detection...");
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
    // print("Faces detected: ${faces.length}");

    if (faces.isNotEmpty) {
      return faces.first.boundingBox;
    } else {
      // print("No face detected.");
    }
    return null;
  }


  Future<Map<String, dynamic>?> detectFaceAndCrop(Uint8List imageBytes) async {
    //print("Running face detection...");
    //print("Input image size: ${imageBytes.length} bytes");

    final faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
    ));

    // Detect faces
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      inputImageData: InputImageData(
        size: Size(480, 640),
        imageRotation: InputImageRotation.Rotation_0deg,
        inputImageFormat: InputImageFormat.BGRA8888,
        planeData: [
          InputImagePlaneMetadata(
            bytesPerRow: 1920,
            height: 640,
            width: 480,
          )
        ],
      ),
    );

    final faces = await faceDetector.processImage(inputImage);
    print("Faces detected: ${faces.length}");

    if (faces.isNotEmpty) {
      try {

        final face = faces.first;

        final boundingBox = face.boundingBox;
        // print("Detected bounding box: $boundingBox");

        // Get eye landmarks
        final leftEye = face.getLandmark(FaceLandmarkType.leftEye)?.position;
        final rightEye = face.getLandmark(FaceLandmarkType.rightEye)?.position;
        if (leftEye != null && rightEye != null) {
          setState(() {
            leftEyePosition = leftEye;
            rightEyePosition = rightEye;
          });
        } else {
          print("Eye landmarks not detected.");
        }

        // Convert BGRA8888 to JPG
        final convertedImage = convertBGRAtoJPG(imageBytes, 480, 640);

        // Crop the face region
        final croppedFace = cropFace(convertedImage, boundingBox);
        // print("Cropped face size: ${croppedFace.length} bytes");

        return {
          'croppedFace': croppedFace,
          'boundingBox': boundingBox,
        };

      } catch (e) {
        print("Error cropping face: $e");
      }

    } else {
      print("No face detected.");
    }

    return null;
  }


  Uint8List cropEye(Uint8List imageBytes, Offset eyePosition, Rect faceBoundingBox, int targetWidth, int targetHeight) {
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) throw Exception("Failed to decode image.");

    // Calculate eye region bounds
    final int eyeX = (faceBoundingBox.left + eyePosition.dx).toInt();
    final int eyeY = (faceBoundingBox.top + eyePosition.dy).toInt();
    final int eyeWidth = (faceBoundingBox.width * 0.2).toInt();
    final int eyeHeight = (faceBoundingBox.height * 0.1).toInt();

    // Clamp to ensure eye region stays within image bounds
    final croppedEye = img.copyCrop(
      decodedImage,
      eyeX.clamp(0, decodedImage.width - 1),
      eyeY.clamp(0, decodedImage.height - 1),
      eyeWidth.clamp(0, decodedImage.width - eyeX),
      eyeHeight.clamp(0, decodedImage.height - eyeY),
    );

    // Resize and normalize
    final resizedEye = img.copyResize(croppedEye, width: targetWidth, height: targetHeight);
    return Uint8List.fromList(img.encodeJpg(resizedEye));
  }




  Uint8List cropFace(Uint8List originalImageBytes, Rect boundingBox) {
    print("Original image size: ${originalImageBytes.length} bytes");

    // Decode the original image
    final decodedImage = img.decodeImage(originalImageBytes);
    if (decodedImage == null) {
      print("Decoded image is null. Check the input image bytes.");
      throw Exception("Failed to decode image.");
    }

    //print("Decoded image dimensions: ${decodedImage.width}x${decodedImage.height}");

    // Calculate and clamp bounding box to image dimensions
    final int x = boundingBox.left.toInt().clamp(0, decodedImage.width - 1);
    final int y = boundingBox.top.toInt().clamp(0, decodedImage.height - 1);
    final int width = boundingBox.width.toInt().clamp(0, decodedImage.width - x);
    final int height = boundingBox.height.toInt().clamp(0, decodedImage.height - y);

    //print("Clamped bounding box: x=$x, y=$y, width=$width, height=$height");

    // Crop the face region
    final croppedFace = img.copyCrop(decodedImage, x, y, width, height);

    //print("Cropped face dimensions: ${croppedFace.width}x${croppedFace.height}");

    // Encode cropped face back to bytes
    return Uint8List.fromList(img.encodeJpg(croppedFace));
  }

  Uint8List preprocessFace(Uint8List faceBytes) {
    final decodedImage = img.decodeImage(faceBytes);
    if (decodedImage == null) throw Exception("Failed to decode face image.");

    // Resize to match model input dimensions (e.g., 224x224)
    final resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

    // Normalize pixel values to [0, 1]
    List<double> normalizedPixels = [];
    for (var pixel in resizedImage.data) {
      normalizedPixels.add(img.getRed(pixel) / 255.0);
      normalizedPixels.add(img.getGreen(pixel) / 255.0);
      normalizedPixels.add(img.getBlue(pixel) / 255.0);
    }

    //print("Preprocessed face data (first 10 values): ${normalizedPixels.take(10).toList()}");
    //print("Input face dimensions: ${resizedImage.width}x${resizedImage.height}");

    return Float32List.fromList(normalizedPixels).buffer.asUint8List();
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
                leftEye: leftEyePosition,
                rightEye: rightEyePosition,
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


