import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_pytorch/pigeon.dart';
import 'package:flutter_pytorch/flutter_pytorch.dart';
import 'package:object_detection/LoaderState.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this line
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';


class SingleImageCap extends StatefulWidget {
  @override
  _SingleImageCapState createState() => _SingleImageCapState();
}

class _SingleImageCapState extends State<SingleImageCap> {

  ModelObjectDetection? _objectModel; // Make nullable
  String? _imagePrediction;
  List? _prediction;
  File? _image;
  ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];
  bool firststate = false;
  bool message = true;
  Map<String, int> uniqueObjectCounts = {};
  Map<String, int> detectionResults = {};

  GlobalKey _repaintBoundaryKey = GlobalKey();

  List<String> savedImagePaths = [];

  String? selectedModel; // Current selected model
  String processingTime = "No image has been processed";


  // Update models dictionary to include label path
  final Map<String, ModelInfo> models = {
    "AppleBananaOrange.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange"),
    "AppleBananaOrangeS10p.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange 10p"),
    "AppleBananaOrange20p.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange 20p"),
    "AppleBananaOrange30p.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange 30p"),
    "AppleBananaOrange40p.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange 40p"),
    "AppleBananaOrange_new.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange New"),
    "AppleBananaOrangeFilteredV2.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange Filtered V2"),

    // "yolovl_kaggle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvL Kaggle 6 Classes"),
    // "yolovx_kaglle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvX Kaggle 6 Classes"),
    // "yolovm_kaggle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvM Kaggle 6 Classes"),
    // "yolovs_kaggle_6cls.torchscript": ModelInfo(classNumber: 6, labelPath: "assets/labels/lb4.txt", name: "YOLOvS Kaggle 6 Classes"),
    // "best_optimized.torchscript": ModelInfo(classNumber: 14, labelPath: "assets/labels/lb2.txt", name: "Best Optimized"),
    // "souvik_only_banana.torchscript": ModelInfo(classNumber: 1, labelPath: "assets/labels/souvik_only_banana.txt", name: "Souvik Banana Only"),
    // "souvik_banana_filtered.torchscript": ModelInfo(classNumber: 1, labelPath: "assets/labels/souvik_only_banana.txt", name: "Souvik Banana Filtered"),
  };


  @override
  void initState() {
    super.initState();
    selectedModel = models.keys.first;
    loadModel(selectedModel).then((_) {
      if (_objectModel == null) {
        showDialogWithMessage("Failed to load the model.");
      } else {
        runObjectDetection();
      }
    });
  }

  // Future<void> loadModel() async {
  //   String pathObjectDetectionModel = "assets/models/best_optimized.torchscript";
  //   try {
  //     _objectModel = await FlutterPytorch.loadObjectDetectionModel(
  //         pathObjectDetectionModel, 14, 640, 640,
  //         labelPath: "assets/labels/lb2.txt");
  //     print("Model loaded successfully");
  //   } catch (e) {
  //     print("Error loading model: $e");
  //     // Consider showing an error message to the user
  //   }
  // }

  Future<void> loadModel(String? modelName) async {
    if (modelName == null || !models.containsKey(modelName)) {
      print("Model name is not valid.");
      return;
    }
    final modelInfo = models[modelName]!;
    final path = "assets/models/${selectedModel}";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(path, modelInfo.classNumber, 640, 640, labelPath: modelInfo.labelPath);
      print("Model loaded successfully.");
    } catch (e) {
      print("Error loading model: $e");
    }
  }


  void handleTimeout() {
    // callback function
    // Do some work.
    setState(() {
      firststate = true;
    });
  }

  Timer scheduleTimeout([int milliseconds = 10000]) =>
      Timer(Duration(milliseconds: milliseconds), handleTimeout);

  // Method to count the total number of unique objects per class
  void countUniqueObjects() {
    uniqueObjectCounts.clear(); // Clear previous counts
    for (var element in objDetect) {
      if (element != null) {
        // Check if element is not null
        var className = element.className;
        if (className != null) {
          uniqueObjectCounts[className] =
              (uniqueObjectCounts[className] ?? 0) + 1;
        }
      }
    }
  }

  Future<void> runObjectDetection() async {
    if (_objectModel == null) {
      showDialogWithMessage("Model is not loaded. Please load a model first.");
      return;
    }
    final XFile? image = await _pickImage();
    if (image == null) {
      showDialogWithMessage("No image selected.");
      return;
    }
    var imageData = await File(image.path).readAsBytes();
    // Initialize the stopwatch
    Stopwatch stopwatch = Stopwatch()..start();
    try {
      objDetect = await _objectModel!.getImagePrediction(imageData, minimumScore: 0.5, IOUThershold: 0.4, boxesLimit: 100);
      countUniqueObjects();
      // Stop the stopwatch immediately after the inference is complete
      stopwatch.stop();
      setState(() {
        _image = File(image.path);
        processingTime = "Processed in: ${stopwatch.elapsedMilliseconds}ms";
      });
    } catch (e) {
      showDialogWithMessage("Failed to run object detection: $e");
    }
  }

  Future<XFile?> _pickImage() async {
    final source = await _showImageSourceDialog();
    if (source == null) return null;
    return await _picker.pickImage(source: source);
  }


  void showDialogWithMessage(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Notification"),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }


  // // Method to pick an image from camera or gallery
  // Future<XFile?> _pickImage() async {
  //   final source = await _showImageSourceDialog();
  //   if (source == null) return null; // If no source is selected, return null
  //
  //   try {
  //     return await _picker.pickImage(source: source);
  //   } catch (e) {
  //     print("Failed to pick image: $e");
  //     return null;
  //   }
  // }

// Show dialog to choose the image source
// Show dialog to choose the image source
  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      barrierDismissible: true,  // Allows dialog to dismiss by tapping outside of the dialog
      builder: (context) => AlertDialog(
        // Reduces padding around the content
        contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 20),  // Adjusts padding specifically
        // Wrapping content in a Container to control height more explicitly
        content: Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,  // Use minimum size that fits the child content
            children: <Widget>[
              // Row to contain the icons
              Row(
                mainAxisSize: MainAxisSize.min,  // Ensures Row size is just enough for its children
                mainAxisAlignment: MainAxisAlignment.center,  // Centers the icons horizontally
                children: [
                  // Camera Icon
                  IconButton(
                    icon: Icon(Icons.camera_alt, size: 50, color: Colors.lightGreen),
                    onPressed: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  // Space between icons
                  SizedBox(width: 20),
                  // Gallery Icon
                  IconButton(
                    icon: Icon(Icons.photo_library, size: 50, color: Colors.orangeAccent),
                    onPressed: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }






  Future<void> checkAndExportToCSV() async {
    await requestPermissions();
    // Proceed with your exportToCSV logic only after permissions are granted
    exportToCSV();
  }


  Future<void> exportToCSV() async {
    // Your CSV data creation logic stays the same
    List<List<dynamic>> csvData = [
      ['Class', 'Count'],
    ];

    uniqueObjectCounts.forEach((key, value) {
      csvData.add([key, value]);
    });

    String csv = const ListToCsvConverter().convert(csvData);

    try {
      // Using the app's temporary directory to store the file temporarily
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/object_counts.csv';

      // Save the CSV file
      final File file = File(filePath);
      await file.writeAsString(csv);
      print('CSV file saved temporarily at $filePath');

      // Sharing the file
      Share.shareFiles([filePath], text: 'Here is the exported CSV file.');
    } catch (e) {
      print('Error saving CSV file: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          // Scrollable content
          ListView(
            children: <Widget>[
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Material(
                    elevation: 0.1,
                    color: Color(0xFFF9FAF2),
                    borderRadius: BorderRadius.circular(5.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Icon(Icons.menu, color: Colors.green),
                          Text(
                            'Farmer Buddy',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                          Icon(Icons.notifications, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Other content widgets here that need to scroll
              // ... // Add other Widgets here as needed.

              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                    topRight: Radius.circular(40.0),
                  ),
                ),
                child: ClipRRect(
                  // borderRadius: BorderRadius.circular(40),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                    topRight: Radius.circular(40.0),
                  ),
                  child: Column(
                    children: [
                      // This part checks if the model is loaded and an image has been picked
                      _objectModel != null && _image != null
                          ? Container(
                        child: _objectModel!.renderBoxesOnImage(_image!, objDetect), // This displays the image with rendered boxes
                        width: double.infinity,
                        height: 230,
                      )
                          :Image.asset(
                        'assets/loading_icon_green_banner.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 230,
                      ),


                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 5.0, 0, 5.0), // Reduced top padding
                        child: Container(
                          height: 130, // Set a fixed height for the scrollable container
                          child: SingleChildScrollView(
                            child: Column(
                              children: uniqueObjectCounts.entries
                                  .map((entry) => CropCounter(crop: entry.key, count: entry.value))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),

                      // Model selection dropdown at the end of the page
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Select Model:",
                              style: TextStyle(
                                fontFamily: 'Quicksand', // Ensure this font is added to your pubspec.yaml
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: 5),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 5.0),
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
                                  dropdownColor: Color(0xffF3F3F3),
                                  // Set the dropdown background color here
                                  onChanged: (String? newValue) {
                                    if (newValue == null || !models.containsKey(newValue)) {
                                      print("Model selection is invalid.");
                                      return;
                                    }
                                    setState(() {
                                      selectedModel = newValue;
                                      loadModel(selectedModel).then((_) {});
                                    });
                                  },
                                  items: models.entries.map((MapEntry<String, ModelInfo> entry) {
                                    return DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10), // Add padding for each item if needed
                                        child: Text(
                                          entry.value.name,
                                          style: TextStyle(
                                            fontFamily: 'Quicksand',
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
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
            ],
          ),
          // Fixed bottom container
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              child: Column(
                children: <Widget>[
                  BarChartWidget(data: uniqueObjectCounts),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      processingTime,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: runObjectDetection,
                        child: Text('Run Again', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFA3D79C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: checkAndExportToCSV,
                        child: Text('Export CSV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFEDAC4A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



}


class CropCounter extends StatelessWidget {
  final String crop;
  final int count;

  CropCounter({required this.crop, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            alignment: Alignment.center,
            width: 160, // Fixed width
            height: 30, // Fixed height
            decoration: BoxDecoration(
              color: Colors.grey[200], // Background color
              borderRadius: BorderRadius.circular(10), // Rounded corners
            ),
            child: Text(
              crop,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center, // Center text
            ),
          ),
          Container(
            alignment: Alignment.center,
            width: 160, // Fixed width
            height: 30, // Fixed height
            decoration: BoxDecoration(
              color: Colors.grey[200], // Background color
              borderRadius: BorderRadius.circular(10), // Rounded corners
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center, // Center text
            ),
          ),
        ],
      ),
    );
  }
}



class BarChartWidget extends StatelessWidget {
  final Map<String, int> data;

  BarChartWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> barGroups = [];
    double maxY = data.values.fold(0, (max, v) => max! > v ? max : v.toDouble());

    int index = 0;
    data.forEach((key, value) {
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              gradient: LinearGradient(
                colors: [Colors.deepPurpleAccent, Colors.purpleAccent], // Refined gradient colors
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 14, // Adjusted bar width for a sleeker look
            ),
          ],
        ),
      );
      index++;
    });

    return Container(
      height: 130, // Reduced height for compactness
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Adjusted padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey, // Set border color
          width: 0.5, // Set border width
        ),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final String text = data.keys.elementAt(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: Text(text, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 5)), // Smaller font size
                  );
                },
                interval: 1,
                reservedSize: 18, // Adjusted for smaller font size
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Text(value.toInt().toString(), style: TextStyle(fontSize: 5)); // Reduced font size for Y-axis
                },
                interval: 1,
                reservedSize: 28, // Adjusted reserved size
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: barGroups,
          borderData: FlBorderData(show: false), // Turned off for a cleaner look
          gridData: FlGridData(
            show: false, // Turned off grid lines for a minimalistic design
          ),
        ),
      ),
    );
  }
}


// Define a ModelInfo class to store model related information
class ModelInfo {
  final int classNumber;
  final String labelPath;
  final String name; // New property for display name

  ModelInfo({required this.classNumber, required this.labelPath, required this.name});
}






