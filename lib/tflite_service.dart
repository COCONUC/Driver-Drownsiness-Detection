import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class TFLiteService {
  late Interpreter _interpreter;

  // Load the model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/drowsiness_model.tflite');
      print("Model loaded successfully!");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  // Run inference
  List<dynamic> runModel(Uint8List inputData) {
    var input = inputData; // Input data preprocessed
    var output = List.filled(1, 0).reshape([1]); // Output placeholder

    try {
      _interpreter.run(input, output);
    } catch (e) {
      print("Error running model: $e");
    }

    return output[0];
  }

  void close() {
    _interpreter.close();
  }
}

class ImageProcessor {
  TensorImage preprocessImage(TensorImage inputImage) {
    // Resize image to model input size
    var imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(224, 224, ResizeMethod.BILINEAR)) // Adjust size
        .add(NormalizeOp(0, 255)) // Normalize pixel values
        .build();

    return imageProcessor.process(inputImage);
  }
}
