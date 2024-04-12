import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';

class TfTest extends StatefulWidget {
  final CameraDescription camera;

  const TfTest({Key? key, required this.camera}) : super(key: key);

  @override
  _TfTestState createState() => _TfTestState();
}

class _TfTestState extends State<TfTest> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.max);

    // Load the model and initialize the camera
    _initializeControllerFuture = loadModel().then((_) {
      return _controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});

        // Start the image stream
        _controller.startImageStream((CameraImage img) {
          if (!isDetecting) {
            isDetecting = true;

            Tflite.runModelOnFrame(
              bytesList: img.planes.map((plane) => plane.bytes).toList(),
              imageHeight: img.height,
              imageWidth: img.width,
              imageMean: 127.5,
              imageStd: 127.5,
              rotation: 90,
              numResults: 6,
              threshold: 0.1,
              asynch: true,
            ).then((recognitions) {
              // Process recognitions
              print(recognitions);

              isDetecting = false;
            });
          }
        });
      });
    });
  }

  @override
  void dispose() {
    // Release the camera and the TensorFlow Lite resources
    _controller.dispose();
    Tflite.close();
    super.dispose();
  }

  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: "assets/models/best_n_2.tflite",
      labels: "assets/labels/lb3.txt",
      numThreads: 1, // defaults to 1
      isAsset: true, // defaults to true
      useGpuDelegate: false, // defaults to false
    );
    print(res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
