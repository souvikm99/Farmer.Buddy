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

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
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
  bool _showOnlyCurrentCount = false;  // New flag for toggling display


  String? selectedModel; // Current selected model
  // Update models dictionary to include label path
  final Map<String, ModelInfo> models = {
    "AppleBananaOrange.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange"),
    "AppleBananaOrangeS10p.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange 10p"),
    // "yolovl_kaggle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvL Kaggle 6 Classes"),
    // "yolovx_kaglle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvX Kaggle 6 Classes"),
    // "yolovm_kaggle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvM Kaggle 6 Classes"),
    // "yolovs_kaggle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvS Kaggle 6 Classes"),
    // "best_optimized.torchscript": ModelInfo(classNumber: 14, labelPath: "assets/labels/lb2.txt", name: "Best Optimized"),
    // "souvik_only_banana.torchscript": ModelInfo(classNumber: 1, labelPath: "assets/labels/souvik_only_banana.txt", name: "Souvik Banana Only"),
    // "souvik_banana_filtered.torchscript": ModelInfo(classNumber: 1, labelPath: "assets/labels/souvik_only_banana.txt", name: "Souvik Banana Filtered"),
    // "": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "No Model"),
  };

  @override
  void initState() {
    super.initState();
    selectedModel = models.keys.first;
    loadModel().then((_) {
      initCamera();
      updateTotalCounts(); // Ensure counts are updated on initial load
    }).catchError((error) {
      print("Error loading model: $error");
    });
  }


  Future<void> loadModel() async {
    final modelInfo = models[selectedModel];
    if (modelInfo == null) { // Check if modelInfo is not null before proceeding
      print("Selected model info is not available.");
      return;
    }

    String pathObjectDetectionModel =  "assets/models/${selectedModel}";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, modelInfo.classNumber, 640, 640,
          labelPath: modelInfo.labelPath);
      clearTrackingData();
      print("Model $selectedModel loaded successfully");
    } catch (e) {
      print("Error loading model: $e");
      rethrow;
    }
  }

  void resetTrackingData() {
    // Step 1: Reset the tracking system
    tracker.reset();

    // Step 2: Clear any additional state or data structures if needed
    // For example, if you maintain separate lists or counters, clear them here
    classWiseTracking.clear();
    totalClassCounts.clear();

    // Step 3: Clear the UI elements by resetting state variables that affect the UI
    setState(() {
      boxes.clear(); // Clear detected boxes on the camera view
      // If there are other elements like charts or graphs displaying data, reset them as well
    });
  }

  void onModelChanged(String? newValue) {
    if (newValue == null || !models.containsKey(newValue)) {
      print("Model selection is invalid.");
      return;
    }
    setState(() {
      selectedModel = newValue;
    });
    loadModel().then((_) {
      resetTrackingData();  // Reset tracking data when model changes
      updateTotalCounts();  // Update total counts based on the new model
      clearTrackingData();
    }).catchError((error) {
      print("Error while loading or resetting model: $error");
    });
  }

  void clearTrackingData() {
    tracker.clearCumulativeCounts(); // Clear the tracking data in the tracker
    resetTrackingData(); // Call existing reset to clear UI and other state
  }


  void updateTotalCounts() {
    // Assuming you have a way to calculate or fetch total counts per model
    totalClassCounts.clear();  // Clear previous counts
    // Example, this could be fetched or calculated, here we just simulate an update
    // Let's assume 'totalClassCounts' is a property of 'tracker'
    totalClassCounts.addAll(tracker.cumulativeClassCounts);

    setState(() {});  // Update the UI to reflect new counts
  }

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
    if (!_isCameraInitialized || imgCamera == null || !mounted) return;
    final stopwatch = Stopwatch()..start();

    final previewSize = cameraPreviewKey.currentContext?.findRenderObject()?.semanticBounds.size;
    final objDetect = await _objectModel.getImagePredictionFromBytesList(
      imgCamera!.planes.map((plane) => plane.bytes).toList(),
      imgCamera!.width,
      imgCamera!.height,
      minimumScore: 0.5,
      IOUThershold: 0.4,
      boxesLimit : 100,
    );

    List<Box> newBoxes = [];
    for (var element in objDetect) {
      final scaleW = previewSize?.width ?? MediaQuery.of(context).size.width;
      final scaleH = previewSize?.height ?? MediaQuery.of(context).size.height;
      double left = element!.rect.left * scaleW;
      double top = element.rect.top * scaleH;
      double width = element.rect.width * scaleW;
      double height = element.rect.height * scaleH;

      newBoxes.add(Box(
        top: top,
        left: left,
        width: width,
        height: height,
        color: Colors.blue,
        className: element.className ?? "Unknown",
        score: element.score,
      ));
    }

    // Always update tracker regardless of toggle state
    tracker.update(newBoxes);

    if (!mounted) return;
    updateBoxes(newBoxes);
    isWorking = false;
    stopwatch.stop();
    setState(() {
      inferenceTime = "Inference: ${stopwatch.elapsedMilliseconds}ms";
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
            ? Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Container(
                        width: MediaQuery.of(context).size.width,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.0)),
                          child: CameraPreview(cameraController, key: cameraPreviewKey),
                        ),
                      ),
                      CustomPaint(
                        size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
                        painter: BoxPainter(boxes: boxes, showIDs: !_showOnlyCurrentCount),
                      ),
                      _buildInferenceTimeDisplay(),
                      _buildClassCountsDisplay(),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30.0),
                      topRight: Radius.circular(30.0),
                    ),
                  ),
                  padding: EdgeInsets.all(16.0),
                  child: _buildModelSelection(),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 20,
              child: IconButton(
                icon: Icon(
                  _showOnlyCurrentCount ? Icons.toggle_off_sharp : Icons.toggle_on_sharp,
                  size: 30,
                  color: _showOnlyCurrentCount ? Colors.grey : Colors.green,
                ),
                onPressed: () {
                  clearTrackingData();
                  setState(() {
                    _showOnlyCurrentCount = !_showOnlyCurrentCount;
                  });
                },
                tooltip: 'Toggle tracking display',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),
          ],
        )
            : Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildModelSelection() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Model:",
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.black12, width: 1),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedModel,
                    icon: Icon(Icons.keyboard_arrow_down, size: 22, color: Colors.black54),
                    elevation: 0,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    onChanged: onModelChanged, // Using the onModelChanged function here
                    items: models.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value.name),
                      );
                    }).toList(),

                  ),
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {
            checkAndExportToCSV();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 80),
            child: Text(
              'Export CSV',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // SizedBox(height: 16), // Spacing
        // _buildClearTrackingButton(), // Add the reset button
      ],
    );
  }


  Widget _buildClearTrackingButton() {
    return ElevatedButton(
      onPressed: () {
        clearTrackingData();  // Call the method to clear tracking data when button is pressed
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent, // Button color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Button shape
        ),
      ),
      child: Text(
        'Reset Tracking',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }


  Widget _buildClassCountsDisplay() {
    // Function to build display string for counts
    String buildCountsDisplay(Map<String, int> counts) {
      return counts.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    }

    // Conditional rendering based on the toggle state
    return Positioned(
      bottom: 20,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        child: Container(
          width: MediaQuery.of(context).size.width - 20,
          child: Column(
            children: [
              Container(
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
                      height: 60,  // Set a fixed height for the scrollable area
                      child: SingleChildScrollView(
                        child: Text(
                          buildCountsDisplay(tracker.classCounts),
                          style: TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_showOnlyCurrentCount)
                Container(
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        height: 100,  // Set a fixed height for the scrollable area
                        child: SingleChildScrollView(
                          child: Text(
                            buildCountsDisplay(tracker.cumulativeClassCounts),
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
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
  final bool showIDs;

  BoxPainter({required this.boxes, required this.showIDs});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF005DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Radius cornerRadius = Radius.circular(8.0);

    for (var box in boxes) {
      final roundedRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(box.left, box.top, box.width, box.height),
        cornerRadius,
      );
      canvas.drawRRect(roundedRect, paint);

      if (showIDs) {
        final String displayText = '${box.id != null ? "ID: ${box.id}, " : ""}${box.className} ${(box.score * 100).toStringAsFixed(2)}%';
        final textStyle = TextStyle(
          color: Color(0xFFCF46F1),
          fontSize: 10,
          backgroundColor: Colors.black54,
        );
        final textSpan = TextSpan(text: displayText, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(minWidth: 0, maxWidth: size.width);
        final offset = Offset(box.left, box.top - 20);
        textPainter.paint(canvas, offset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class EuclideanDistTracker {
  final Map<int, math.Point<double>> centerPoints = {};
  Map<int, int> lostFrames = {};
  int idCount = 0;
  final int maxLostFrames = 10;
  Map<String, int> classCounts = {}; // For current frame counts
  Map<String, Set<int>> cumulativeClassIds = {}; // Tracks unique IDs for each class cumulatively

  void reset() {
    centerPoints.clear();
    lostFrames.clear();
    idCount = 0;
    classCounts.clear();
    cumulativeClassIds.clear(); // Reset all tracking data
  }

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

  void clearCumulativeCounts() {
    cumulativeClassIds.clear(); // Clears all cumulative tracking data
  }

}

// Define a ModelInfo class to store model related information
class ModelInfo {
  final int classNumber;
  final String labelPath;
  final String name; // New property for display name

  ModelInfo({required this.classNumber, required this.labelPath, required this.name});
}

