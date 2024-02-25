import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:object_detection/LoaderState.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ModelObjectDetection _objectModel;
  File? _image;
  ImagePicker _picker = ImagePicker();
  bool firststate = false;
  bool message = true;
  int detectedObjectsCount = 0;
  Map<String, int> detectedObjectsPerClass = {};
  List<ResultObjectDetection?> objDetect = []; // Define objDetect here

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future loadModel() async {
    String pathObjectDetectionModel = "assets/models/best_yolov5l.torchscript";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, 14, 640, 640, labelPath: "assets/labels/lb2.txt");
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
    }
  }

  Timer scheduleTimeout([int milliseconds = 10000]) => Timer(Duration(milliseconds: milliseconds), handleTimeout);

  void handleTimeout() {
    setState(() {
      firststate = true;
    });
  }

  Future runObjectDetection() async {
    setState(() {
      firststate = false;
      message = false;
      detectedObjectsCount = 0;
      detectedObjectsPerClass.clear();
    });

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    objDetect = await _objectModel.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.1,
        IOUThershold: 0.3);

    for (var detection in objDetect) {
      final className = detection?.className ?? 'Unknown';
      detectedObjectsPerClass.update(className, (value) => value + 1, ifAbsent: () => 1);
    }

    detectedObjectsCount = objDetect.length;

    detectedObjectsPerClass.forEach((key, value) {
      print("$key: $value");
    });

    scheduleTimeout(5 * 1000);
    setState(() {
      _image = File(image.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("OBJECT DETECTOR APP")),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            !firststate
                ? !message ? LoaderState() : Text("Select the Camera to Begin Detections")
                : Expanded(
              child: Container(
                child: Column(
                  children: [
                    Text("Detected Objects: $detectedObjectsCount"),
                    ...detectedObjectsPerClass.entries.map((entry) => Text("${entry.key}: ${entry.value}")).toList(),
                    Expanded(
                      child: _image != null ? _objectModel.renderBoxesOnImage(_image!, objDetect) : Container(),
                    ),
                  ],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                runObjectDetection();
              },
              child: const Icon(Icons.camera_alt_outlined),
            )
          ],
        ),
      ),
    );
  }
}
