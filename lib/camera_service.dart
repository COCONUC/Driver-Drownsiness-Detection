import 'package:camera/camera.dart';
import 'dart:typed_data';


class CameraService{
  late CameraController _controller;
  bool _isInitialized = false; // Add flag to track initialization

  Future<void> initialize() async {
    final cameras = await availableCameras();
    // Select the front camera
    final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => throw Exception("No front camera found!"),
    );
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
    );
    await _controller.initialize();
    _isInitialized = true; // Set flag to true after initialization
  }

  Future<Uint8List> captureImage() async {
    if (!_isInitialized) {
      throw Exception("Camera is not initialized. Call initialize() first.");
    }
    try {
      final XFile file = await _controller.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      print("Error capturing image: $e");
      rethrow; // Rethrow error for further handling
    }
  }

  CameraController get controller {
    if (!_isInitialized) {
      throw Exception("Camera is not initialized. Call initialize() first.");
    }
    return _controller;
  }

  void dispose() {
    _controller.dispose();
  }
}