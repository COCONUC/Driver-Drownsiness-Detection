import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class TFLiteService {
  late Interpreter _interpreter;

  // Load the model once during initialization
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/drowsiness_detection_model.tflite');
      print("Model loaded successfully!");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  // Run inference synchronously
  List<dynamic> runModel(Uint8List inputData) {
    var input = inputData; // Input must match model requirements
    var output = List.filled(1, 0).reshape([1]); // Output placeholder

    try {
      _interpreter.run(input, output);
      print("Inference Output: $output");
      return output[0];
    } catch (e) {
      print("Error running model: $e");
      return ["Error"];
    }
  }

  // Close the interpreter safely
  void close() {
    _interpreter.close();
  }


  TensorImage preprocessImage(Uint8List imageData) {
    // Decode image using the 'image' package
    img.Image? decodedImage = img.decodeImage(imageData);
    if (decodedImage == null) {
      throw Exception("Failed to decode image.");
    }

    // Convert decoded image to TensorImage
    TensorImage tensorImage = TensorImage.fromImage(decodedImage);

    // Create an ImageProcessor with resize and normalization steps
    var imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(224, 224, ResizeMethod.BILINEAR)) // Resize to model input size
        .add(NormalizeOp(0, 255)) // Normalize pixel values to [0, 1]
        .build();

    return imageProcessor.process(tensorImage);
  }

  String interpretOutput(List<dynamic> output) {
    return output[0] == 1 ? "Drowsy" : "Alert";
  }

}

class InputProcessor {

  TensorImage preprocessImage(Uint8List imageData) {
    // Decode image using the 'image' package
    img.Image? decodedImage = img.decodeImage(imageData);
    if (decodedImage == null) {
      throw Exception("Failed to decode image.");
    }

    // Convert decoded image to TensorImage
    TensorImage tensorImage = TensorImage.fromImage(decodedImage);

    // Create an ImageProcessor with resize and normalization steps
    var imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(224, 224, ResizeMethod.BILINEAR)) // Resize to model input size
        .add(NormalizeOp(0, 255)) // Normalize pixel values to [0, 1]
        .build();

    return imageProcessor.process(tensorImage);
  }


  // TensorImage preprocessImage(TensorImage inputImage) {
  //   var imageProcessor = ImageProcessorBuilder()
  //       .add(ResizeOp(224, 224, ResizeMethod.BILINEAR)) // Resize to input shape
  //       .add(NormalizeOp(0, 255)) // Normalize pixel values to [0, 1]
  //       .build();
  //
  //   return imageProcessor.process(inputImage);
  // }

}
