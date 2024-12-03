import 'package:flutter/services.dart';

class MediaPipeChannel {
  static const platform = MethodChannel('com.example.driver_drowsiness_detection/mediapipe');

  static Future<String> processImageWithPath(String imagePath) async {
    try {
      final String result = await platform.invokeMethod('processImageWithPath', {'imagePath': imagePath});
      return result;
    } catch (e) {
      return "Failed to process image: ${e.toString()}";
    }
  }
}
