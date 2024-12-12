import 'package:camera/camera.dart';
import 'dart:typed_data';


class CameraService{
  static late CameraController _controller;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );
    await _controller.initialize();
  }

  static Future<Uint8List> captureImage() async {
    final XFile file = await _controller.takePicture();
    return await file.readAsBytes(); // Get image bytes
  }

  void dispose() {
    _controller.dispose();
  }
}