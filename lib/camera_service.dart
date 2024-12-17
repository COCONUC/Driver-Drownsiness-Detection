import 'package:camera/camera.dart';
import 'dart:typed_data';


class CameraService{
  late CameraController _cameraController;
  bool _isInitialized = false; // Add flag to track initialization
  bool _isCapturing = false; // Add a flag to manage concurrent captures


  Future<void> initialize() async {
    final cameras = await availableCameras();
    // Select the front camera
    final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => throw Exception("No front camera found!"),
    );
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false
    );
    await _cameraController.initialize();
    _isInitialized = true; // Set flag to true after initialization
  }

  Future<Uint8List> captureImage() async {
    if (!_isInitialized) {
      throw Exception("Camera is not initialized. Call initialize() first.");
    }
    // Check if a capture is already in progress
    if (_isCapturing) {
      throw Exception("Previous capture has not returned yet.");
    }

    try {
      _isCapturing = true; // Set capturing flag
      final XFile file = await _cameraController.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      print("Error capturing image: $e");
      rethrow; // Rethrow error for further handling
    } finally{
      _isCapturing = false; // Reset capturing flag
    }
  }

  CameraController get controller {
    if (!_isInitialized) {
      throw Exception("Camera is not initialized. Call initialize() first.");
    }
    return _cameraController;
  }

  void dispose() {
    _cameraController.dispose();
  }
}