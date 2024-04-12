import 'dart:io' as io;

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'scraps/test_overlay.dart';
import 'dart:math' as math;

import 'main.dart'; // Ensure this import points to your main.dart where 'cameras' list is defined

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  late CameraController cameraController;
  bool _isCameraInitialized = false;
  CameraImage? imgCamera;
  bool isWorking = false;
  late ModelObjectDetection _objectModel;
  List<Box> boxes = [];
  final GlobalKey cameraPreviewKey = GlobalKey();
  int frameSkipCount = 0;
  Timer? _debounce;
  String inferenceTime = "Inference time: 0ms"; // Variable to store inference time
  EuclideanDistTracker tracker = EuclideanDistTracker();
  // New mapping for class-wise tracking of unique IDs
  Map<String, Set<int>> classWiseTracking = {};
  // Global dictionary to keep track of total trackwise counting
  Map<String, int> totalClassCounts = {};


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
    String pathObjectDetectionModel = "assets/models/best_25prune_640.torchscript";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, 6, 640, 640, labelPath: "assets/labels/lb3.txt");
    } catch (e) {
      print("Error loading model: $e");
      rethrow;
    }
  }

  // void initCamera() {
  //   cameraController = CameraController(cameras![0], ResolutionPreset.high);
  //   cameraController.initialize().then((_) {
  //     if (!mounted) {
  //       return;
  //     }
  //     setState(() {
  //       cameraController.startImageStream((imageFromStream) {
  //         if (!isWorking && frameSkipCount++ % 5 == 0) {
  //           isWorking = true;
  //           imgCamera = imageFromStream;
  //           runObjectDetection();
  //         }
  //       });
  //     });
  //   }).catchError((error) {
  //     print("Error initializing camera: $error");
  //   });
  // }

  void initCamera() {
    cameraController = CameraController(cameras![0], ResolutionPreset.high);
    cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCameraInitialized = true;
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
    if (!_isCameraInitialized || imgCamera == null || !mounted) return; // Check if the camera is initialized here
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
      inferenceTime = "Inference: ${stopwatch.elapsedMilliseconds}ms"; // Update inference time
    });
  }

  Future<void> requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  Future<void> checkAndExportToCSV() async {
    await requestPermissions();
    // Proceed with your exportToCSV logic only after permissions are granted
    exportToCSV();
  }

  Future<void> exportToCSV() async {
    // Ensure permissions are granted
    await requestPermissions();

    // Convert the data to CSV format
    List<List<dynamic>> csvData = [
      ['Class', 'Count'],
    ];

    // Fill csvData with cumulative class counts from tracker
    tracker.cumulativeClassCounts.forEach((className, count) {
      csvData.add([className, count]);
    });

    // Convert the data to CSV format
    String csv = const ListToCsvConverter().convert(csvData);

    try {
      // Get the temporary directory
      final io.Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/detection_counts.csv';

      // Save the CSV file at the path
      final io.File file = io.File(filePath);
      await file.writeAsString(csv);
      // Log the file path or share the file
      print('CSV file saved temporarily at $filePath');
      Share.shareFiles([filePath], text: 'Here is the exported CSV file.');
    } catch (e) {
      print('Error saving CSV file: $e');
    }
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
    if (_isCameraInitialized) { // Only attempt to stop and dispose if initialized
      cameraController.stopImageStream();
      cameraController.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isCameraInitialized
            ? Column(
          children: [
            Expanded(
              child: Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.0)),
                    child: CameraPreview(cameraController, key: cameraPreviewKey),
                  ),
                  CustomPaint(
                    size: Size.infinite,
                    painter: BoxPainter(boxes: boxes),
                  ),
                  _buildInferenceTimeDisplay(),
                  _buildClassCountsDisplay(), // Display class counts here
                ],
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white, // Container with white background
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30.0),
                  topRight: Radius.circular(30.0),
                ),
              ),
              padding: EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  // Implement your export CSV functionality
                  checkAndExportToCSV();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange, // Button background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Export CSV',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Button text color
                    ),
                  ),
                ),
              ),
            ),
          ],
        )
            : Center(child: CircularProgressIndicator()), // Show loading spinner until the camera is ready
      ),
    );
  }


  Widget _buildClassCountsDisplay() {
    // Function to build display string for counts
    String buildCountsDisplay(Map<String, int> counts) {
      return counts.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    }

    // Container for "Current" counts
// Updated Container for "Current" counts with fixed label and scrollable counts
    Widget currentCountsContainer() {
      return Container(
        width: MediaQuery.of(context).size.width - 20,
        margin: EdgeInsets.only(bottom: 8.0), // Space between the containers
        decoration: BoxDecoration(
          color: Color(0x1ADC1A1A), // Semi-transparent green color
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Current:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                // color: Color(0x1A66ff33), // Same as parent for seamless design
                borderRadius: BorderRadius.circular(8),
              ),
              // Using ConstrainedBox to specify height
              // constraints: BoxConstraints(maxHeight: 100), // Set a maximum height
              height: 60,
              child: SingleChildScrollView(
                child: Text(
                  buildCountsDisplay(tracker.classCounts),
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }

// Updated Container for "Total" counts with fixed label and scrollable counts
    Widget totalCountsContainer() {
      return Container(
        width: MediaQuery.of(context).size.width - 20,
        decoration: BoxDecoration(
          color: Color(0x3300FFF0), // Semi-transparent teal color
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Total:",
                style: TextStyle(fontSize: 12,fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                // color: Color(0x3300FFF0), // Same as parent for seamless design
                borderRadius: BorderRadius.circular(8),
              ),
              // Using ConstrainedBox to specify height
              // constraints: BoxConstraints(maxHeight: 120), // Adjust this as needed
              height: 100,
              child: SingleChildScrollView(
                child: Text(
                  buildCountsDisplay(tracker.cumulativeClassCounts),
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    }


    return Positioned(
      bottom: 20,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        child: Container(
          width: MediaQuery.of(context).size.width - 20,
          decoration: BoxDecoration(
            // color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                child: currentCountsContainer(),
              ),
              SizedBox(height: 5), // Gap between the sections
              SingleChildScrollView(
                child: totalCountsContainer(),
              ),
            ],
          ),
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
          color: Color(0x66EDAC4A), // Match the AppBar color
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          inferenceTime,
          style: const TextStyle(
            fontSize: 8,
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
      ..color = Color(0xFF005DFF) // Box color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Border thickness

    // Define the border radius of the corners
    final Radius cornerRadius = Radius.circular(8.0);

    for (var box in boxes) {
      // Create a rounded rectangle from the bounding box coordinates
      final roundedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(box.left, box.top, box.width, box.height),
        cornerRadius,
      );
      // Draw the rounded rectangle
      canvas.drawRRect(roundedRect, paint);

      // Prepare the text to display. Include the ID if available.
      final String displayText = '${box.id != null ? "ID: ${box.id}, " : ""}${box.className} ${(box.score * 100).toStringAsFixed(2)}%';
      final textStyle = TextStyle(
        color: Color(0xFFCF46F1), // Text color
        fontSize: 10,
        backgroundColor: Colors.black54, // Background color for text
      );
      final textSpan = TextSpan(text: displayText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

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




// class EuclideanDistTracker {
//   final Map<int, math.Point<double>> centerPoints = {};
//   Map<int, int> lostFrames = {};
//   int idCount = 0;
//   final int maxLostFrames = 10;
//
//   void update(List<Box> boxes) {
//     final Map<int, math.Point<double>> newCenterPoints = {};
//     Map<int, int> newLostFrames = Map.from(lostFrames);
//
//     lostFrames.forEach((id, count) {
//       newLostFrames[id] = count + 1;
//     });
//
//     for (final box in boxes) {
//       final cx = box.left + box.width / 2;
//       final cy = box.top + box.height / 2;
//       final currentCenter = math.Point<double>(cx, cy);
//
//       bool sameObjectDetected = false;
//       int? closestId;
//       double minDistance = double.infinity;
//
//       centerPoints.forEach((id, point) {
//         final dist = math.sqrt(math.pow(currentCenter.x - point.x, 2) + math.pow(currentCenter.y - point.y, 2));
//
//         if (dist < minDistance) {
//           minDistance = dist;
//           closestId = id;
//         }
//       });
//
//       if (closestId != null && minDistance < 50.0) { // Assuming 50.0 as the distance threshold for matching
//         newCenterPoints[closestId!] = currentCenter;
//         newLostFrames.remove(closestId);
//         sameObjectDetected = true;
//         box.id = closestId; // Assign the tracked object's ID to the new detection
//       }
//
//       if (!sameObjectDetected) {
//         // This is a new object, assign a new ID
//         box.id = idCount++;
//         newCenterPoints[box.id!] = currentCenter;
//       }
//     }
//
//     // Remove objects that have been lost for too many frames
//     newLostFrames.forEach((id, count) {
//       if (count > maxLostFrames) {
//         newLostFrames.remove(id);
//         centerPoints.remove(id);
//       }
//     });
//
//     // Update tracking information with new detections
//     centerPoints.clear();
//     centerPoints.addAll(newCenterPoints);
//     lostFrames = newLostFrames;
//   }
// }

class EuclideanDistTracker {
  final Map<int, math.Point<double>> centerPoints = {};
  Map<int, int> lostFrames = {};
  int idCount = 0;
  final int maxLostFrames = 10;
  Map<String, int> classCounts = {}; // For current frame counts
  Map<String, Set<int>> cumulativeClassIds = {}; // Tracks unique IDs for each class cumulatively

  void update(List<Box> boxes) {
    final Map<int, math.Point<double>> newCenterPoints = {};
    Map<int, int> newLostFrames = Map.from(lostFrames);

    // Reset current frame class counts
    classCounts.clear();

    for (final box in boxes) {
      final cx = box.left + box.width / 2;
      final cy = box.top + box.height / 2;
      final currentCenter = math.Point<double>(cx, cy);

      bool sameObjectDetected = false;
      int? closestId;
      double minDistance = double.infinity;

      centerPoints.forEach((id, point) {
        final dist = math.sqrt((currentCenter.x - point.x) * (currentCenter.x - point.x) + (currentCenter.y - point.y) * (currentCenter.y - point.y));
        if (dist < minDistance) {
          minDistance = dist;
          closestId = id;
        }
      });

      if (closestId != null && minDistance < 50.0) { // Threshold for matching
        newCenterPoints[closestId!] = currentCenter;
        newLostFrames.remove(closestId);
        sameObjectDetected = true;
        box.id = closestId; // Assign the tracked object's ID to the new detection
      }

      if (!sameObjectDetected) {
        box.id = idCount;
        newCenterPoints[idCount] = currentCenter;
        idCount++;
      }

      // Update class count for the current frame
      if (box.id != null) {
        classCounts[box.className] = (classCounts[box.className] ?? 0) + 1;
        // Update cumulative class-wise unique ID tracking
        cumulativeClassIds.putIfAbsent(box.className, () => <int>{});
        cumulativeClassIds[box.className]!.add(box.id!);
      }
    }

    // Increment lost frame count for all tracked objects
    lostFrames.forEach((id, count) {
      newLostFrames[id] = count + 1;
    });

    // Remove objects that have been lost for too long
    newLostFrames.forEach((id, count) {
      if (count > maxLostFrames) {
        newLostFrames.remove(id);
        centerPoints.remove(id);
      }
    });

    centerPoints.clear();
    centerPoints.addAll(newCenterPoints);
    lostFrames = newLostFrames;
  }

  // Getter to calculate and return cumulative class counts from unique IDs
  Map<String, int> get cumulativeClassCounts {
    Map<String, int> counts = {};
    cumulativeClassIds.forEach((className, ids) {
      counts[className] = ids.length; // The count is the number of unique IDs seen for this class
    });
    return counts;
  }
}


