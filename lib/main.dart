import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle, MethodChannel;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  MyApp({required this.cameras});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late CameraController controller;
  bool isDrowsy = false;
  static const detectionChannel = MethodChannel('com.yourapp/face_detection');

  @override
  void initState() {
    super.initState();
    controller = CameraController(
        widget.cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front),
        ResolutionPreset.medium,
        enableAudio: false
    );
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.startImageStream((image) async {
        // Convert YUV to JPEG here
        Uint8List? jpegBytes = await convertYUV420toJpeg(image);
        if (jpegBytes != null) {
          bool drowsy = await detectDrowsiness(jpegBytes);
          setState(() {
            isDrowsy = drowsy;
          });
        }
      });
    });
  }

  Future<bool> detectDrowsiness(Uint8List imageBytes) async {
    final result = await detectionChannel.invokeMethod("detectDrowsiness", {"image": imageBytes});
    return result == true;
  }

  // Implement convertYUV420toJpeg function or find a plugin
  Future<Uint8List?> convertYUV420toJpeg(CameraImage image) async {
    // This step needs conversion logic. One approach:
    // 1. Use an Isolate or platform channel to convert YUV->JPEG
    // 2. Or capture the image in ImageFormatGroup.jpeg if possible.
    // For simplicity, consider switching camera to output JPEG if supported.
    return null; // TODO: Implement conversion
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            CameraPreview(controller),
            Positioned(
              bottom: 50,
              left: 50,
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.all(8),
                child: Text(
                  isDrowsy ? "DROWSY" : "AWAKE",
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
