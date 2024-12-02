import 'package:flutter/services.dart';

class MediaPipeChannel {
  static const platform = MethodChannel('com.example.driver_drowsiness_detection/mediapipe');

  static Future<String> processImage() async {
    try {
      final String result = await platform.invokeMethod('processImage');
      return result;
    } catch (e) {
      return "Failed to process image: ${e.toString()}";
    }
  }
}
