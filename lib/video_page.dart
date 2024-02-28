import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'dart:async';
import 'scraps/test_overlay.dart';
import 'dart:math' as math;

import 'main.dart'; // Ensure this import points to your main.dart where 'cameras' list is defined

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  late CameraController cameraController;
  CameraImage? imgCamera;
  bool isWorking = false;
  late ModelObjectDetection _objectModel;
  List<Box> boxes = [];
  final GlobalKey cameraPreviewKey = GlobalKey();
  int frameSkipCount = 0;
  Timer? _debounce;
  String inferenceTime = "Inference time: 0ms"; // Variable to store inference time
  EuclideanDistTracker tracker = EuclideanDistTracker();

  @override
  void initState() {
    super.initState();
    loadModel().then((_) {
      initCamera();
    }).catchError((error) {
      print("Error loading model: $error");
    });
  }

  Future<void> loadModel() async {
    String pathObjectDetectionModel = "assets/models/best_optimized.torchscript";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, 14, 640, 640, labelPath: "assets/labels/lb2.txt");
    } catch (e) {
      print("Error loading model: $e");
      rethrow;
    }
  }

  void initCamera() {
    cameraController = CameraController(cameras![0], ResolutionPreset.high);
    cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        cameraController.startImageStream((imageFromStream) {
          if (!isWorking && frameSkipCount++ % 5 == 0) {
            isWorking = true;
            imgCamera = imageFromStream;
            runObjectDetection();
          }
        });
      });
    }).catchError((error) {
      print("Error initializing camera: $error");
    });
  }

  Future<void> runObjectDetection() async {
    if (imgCamera == null || !mounted) return;
    final stopwatch = Stopwatch()..start(); // Start the stopwatch

    final previewSize = cameraPreviewKey.currentContext?.findRenderObject()?.semanticBounds.size;

    final objDetect = await _objectModel.getImagePredictionFromBytesList(
      imgCamera!.planes.map((plane) => plane.bytes).toList(),
      imgCamera!.width,
      imgCamera!.height,
    );

    List<Box> newBoxes = [];
    for (var element in objDetect) {
      print({
        "score": element?.score,
        "className": element?.className,
        "class": element?.classIndex,
        "rect": {
          "left": element?.rect.left,
          "top": element?.rect.top,
          "width": element?.rect.width,
          "height": element?.rect.height,
          "right": element?.rect.right,
          "bottom": element?.rect.bottom,
        },
      });

      final scaleW = previewSize?.width ?? MediaQuery.of(context).size.width;
      final scaleH = previewSize?.height ?? MediaQuery.of(context).size.height;

      double left = element!.rect.left * scaleW;
      double top = element.rect.top * scaleH;
      double width = element.rect.width * scaleW;
      double height = element.rect.height * scaleH;
      String className = element.className ?? "Unknown";

      newBoxes.add(Box(
        top: top,
        left: left,
        width: width,
        height: height,
        color: Colors.blue,
        className: className,
        score: element.score,
      ));
    }

    tracker.update(newBoxes);

    if (!mounted) return; // Check if the widget is still in the tree before calling setState
    updateBoxes(newBoxes);
    isWorking = false;
    stopwatch.stop(); // Stop the stopwatch
    if (!mounted) return; // Another check before calling setState
    setState(() {
      inferenceTime = "Inference time: ${stopwatch.elapsedMilliseconds}ms"; // Update inference time
    });
  }


  void updateBoxes(List<Box> newBoxes) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          boxes = newBoxes;
        });
      }
    });
  }

  @override
  void dispose() {
    cameraController.stopImageStream();
    cameraController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Object Detector Live"),
        backgroundColor: Colors.deepPurple, // Updated color
        elevation: 0,
      ),
      backgroundColor: Colors.black, // Updated background color for consistency
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            CameraPreview(cameraController, key: cameraPreviewKey),
            CustomPaint(
              size: Size.infinite,
              painter: BoxPainter(boxes: boxes),
            ),
            _buildInferenceTimeDisplay(), // Updated UI for inference time display
          ],
        ),
      ),
    );
  }

  Widget _buildInferenceTimeDisplay() {
    // Creates a more visually appealing display for the inference time
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.deepPurple, // Match the AppBar color
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          inferenceTime,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class Box {
  final double top;
  final double left;
  final double width;
  final double height;
  final Color color;
  final String className;
  final double score;
  int? id; // Nullable to accommodate boxes not yet assigned an ID

  Box({
    required this.top,
    required this.left,
    required this.width,
    required this.height,
    required this.color,
    required this.className,
    required this.score,
    this.id,
  });
}


class BoxPainter extends CustomPainter {
  final List<Box> boxes;

  BoxPainter({required this.boxes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (var box in boxes) {
      // Draw the rectangle
      canvas.drawRect(Rect.fromLTWH(box.left, box.top, box.width, box.height), paint);

      // Prepare the text to display. Include the ID if available.
      final String displayText = '${box.id != null ? "ID: ${box.id}, " : ""}${box.className} ${(box.score * 100).toStringAsFixed(2)}%';
      final textStyle = TextStyle(color: Colors.red, fontSize: 12, backgroundColor: Colors.black54);
      final textSpan = TextSpan(text: displayText, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);

      textPainter.layout(minWidth: 0, maxWidth: size.width);
      // Adjust the offset if you want the text to appear above, below, or next to the box
      final offset = Offset(box.left, box.top - 20); // Move the text a bit higher than the top of the box
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // You could optimize this to only repaint when boxes change
  }
}




class EuclideanDistTracker {
  final Map<int, math.Point<double>> centerPoints = {};
  Map<int, int> lostFrames = {};
  int idCount = 0;
  final int maxLostFrames = 10;

  void update(List<Box> boxes) {
    final Map<int, math.Point<double>> newCenterPoints = {};
    Map<int, int> newLostFrames = Map.from(lostFrames);

    lostFrames.forEach((id, count) {
      newLostFrames[id] = count + 1;
    });

    for (final box in boxes) {
      final cx = box.left + box.width / 2;
      final cy = box.top + box.height / 2;
      final currentCenter = math.Point<double>(cx, cy);

      bool sameObjectDetected = false;
      int? closestId;
      double minDistance = double.infinity;

      centerPoints.forEach((id, point) {
        final dist = math.sqrt(math.pow(currentCenter.x - point.x, 2) + math.pow(currentCenter.y - point.y, 2));

        if (dist < minDistance) {
          minDistance = dist;
          closestId = id;
        }
      });

      if (closestId != null && minDistance < 50.0) { // Assuming 50.0 as the distance threshold for matching
        newCenterPoints[closestId!] = currentCenter;
        newLostFrames.remove(closestId);
        sameObjectDetected = true;
        box.id = closestId; // Assign the tracked object's ID to the new detection
      }

      if (!sameObjectDetected) {
        // This is a new object, assign a new ID
        box.id = idCount++;
        newCenterPoints[box.id!] = currentCenter;
      }
    }

    // Remove objects that have been lost for too many frames
    newLostFrames.forEach((id, count) {
      if (count > maxLostFrames) {
        newLostFrames.remove(id);
        centerPoints.remove(id);
      }
    });

    // Update tracking information with new detections
    centerPoints.clear();
    centerPoints.addAll(newCenterPoints);
    lostFrames = newLostFrames;
  }
}
