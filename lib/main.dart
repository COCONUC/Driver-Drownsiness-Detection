import 'package:driver_drownsiness_detection/tflite_service.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'mediapipe_channel.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:driver_drownsiness_detection/camera_service.dart';
import 'dart:async';

final TFLiteService _tfliteService = TFLiteService();
final CameraService _cameraService = CameraService();
List<CameraDescription> cameras = [];

String interpretOutput(List<dynamic> output) {
  return output[0] == 1 ? "Drowsy" : "Alert";
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Camera
  cameras = await availableCameras();
  // Load TensorFlow Lite model
  await _tfliteService.loadModel();
  try {
    await _cameraService.initialize(); // Initialize the camera
  } catch (e) {
    print("Error initializing camera: $e");
  }
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
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  String detectionResult = 'No Result';
  Timer? _timer;


  @override
  void initState() {
    super.initState();

    // Find the front camera from the list of available cameras
    CameraDescription? frontCamera;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    // Initialize the controller with the front camera
    if (frontCamera != null) {
      _controller = CameraController(frontCamera, ResolutionPreset.high);
      _initializeControllerFuture = _controller.initialize();
    } else {
      // Handle case where no front camera is found
      print('Front camera not available');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _cameraService.dispose();
    _tfliteService.close();
    super.dispose();
  }

  void updateResult(String result) {
    setState(() {
      detectionResult = result;
    });
  }

  String detectDrowsiness(Uint8List imageBytes){
    var result = _tfliteService.runModel(imageBytes);
    print("Detection Result: $result");

    // Check the type of result and handle appropriately
    if (result is int) {
      print("Result is an integer: $result");
    } else if (result is List) {
      print("Result is a list: $result");
    } else {
      print("Unknown result type: ${result.runtimeType}");
    }

    final InputProcessor processor = InputProcessor();

    // Preprocess the input image
    TensorImage inputImage = processor.preprocessImage(imageBytes);

    // Perform inference
    List<dynamic> output = _tfliteService.runModel(inputImage.buffer.asUint8List());

    // Interpret the output
    String prediction = interpretOutput(output);
    print("Prediction: $prediction");
    return interpretOutput(output);
  }

  // Start periodic detection
  void startDetection() {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) async {
      try {
        // Capture a frame from the camera
        Uint8List imageBytes = await _cameraService.captureImage();

        // Run inference using the TensorFlow Lite model
        String result = detectDrowsiness(imageBytes);

        // Update the detection result on the UI
        setState(() {
          detectionResult = result;
        });

        print("Detection Result: $result");
      } catch (e) {
        print("Error during detection: $e");
      }
    });
  }

  // void _processImage() async {
  //   String result = await MediaPipeChannel.processImage();
  //   setState(() {
  //     detectionResult = result; // Use this to update the UI accordingly
  //   });
  // }

  void _captureFrame() async {
    try {
      // Capture the current frame
      final image = await _controller.takePicture();

      // Send the image path to the native side via platform channel
      String result = await MediaPipeChannel.processImageWithPath(image.path);
      setState(() {
        detectionResult = result;
      });
    } catch (e) {
      print('Error capturing frame: $e');
    }
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
          FutureBuilder(future: _cameraService.initialize(), builder: (context, snapshot){
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error initializing camera"));
            } else {
              return CameraPreview(_cameraService.controller); // Show preview
            }
          },
          ),
          ElevatedButton(
            onPressed: startDetection,
            child: Text("Start"),
          ),
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          if (detectionResult.isNotEmpty)
            Container(
              color: detectionResult.contains("Drowsiness") ? Colors.red : Colors.green,
              height: 50,
              child: Center(
                child: Text(
                  detectionResult,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: Text(
                "Detection Result: $detectionResult",
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Uint8List imageBytes = await _cameraService.captureImage();
                print("Image captured successfully!");
                String result = detectDrowsiness(imageBytes);
                updateResult(result);
                // Add code to process or display the image
              } catch (e) {
              print("Error capturing image: $e");
              }
              // Capture image and run inference
            },
            child: Text('Detect Drowsiness'),
          ),
        ],
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
