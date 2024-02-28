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

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ModelObjectDetection _objectModel;
  String? _imagePrediction;
  List? _prediction;
  File? _image;
  ImagePicker _picker = ImagePicker();
  bool objectDetection = false;
  List<ResultObjectDetection?> objDetect = [];
  bool firststate = false;
  bool message = true;
  Map<String, int> uniqueObjectCounts = {};

  @override
  void initState() {
    super.initState();
    loadModel();
    runObjectDetection();
  }

  Future loadModel() async {
    String pathObjectDetectionModel = "assets/models/best_optimized.torchscript";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, 14, 640, 640,
          labelPath: "assets/labels/lb2.txt");
    } catch (e) {
      if (e is PlatformException) {
        print("only supported for android, Error is $e");
      } else {
        print("Error is $e");
      }
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

  //running detections on image
  Future runObjectDetection() async {
    setState(() {
      firststate = false;
      message = false;
    });
    //pick an image
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    objDetect = await _objectModel.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.1,
        IOUThershold: 0.3);
    objDetect.forEach((element) {
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
    });
    countUniqueObjects(); // Count unique objects after detection
    scheduleTimeout(5 * 1000);
    setState(() {
      _image = File(image.path);
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
      appBar: AppBar(
        title: Text("OBJECT DETECTOR APP"),
        backgroundColor: Colors.deepPurple, // Change app bar color to purple
      ),
      backgroundColor: Colors.deepPurple, // Change background color to purple
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image with Detections....
            !firststate
                ? !message
                ? LoaderState()
                : Text("Select the Camera to Begin Detections")
                : Expanded(
              child: Container(
                child:
                _objectModel.renderBoxesOnImage(_image!, objDetect),
              ),
            ),
            SizedBox(height: 20),
            // Display unique object counts
            Container(
              height: 200, // Fixed height for the container
              child: ListView(
                children: uniqueObjectCounts.entries.map((entry) => ListTile(
                  title: Text(
                    entry.key,
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  trailing: Text(
                    entry.value.toString(),
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                )).toList(),
              ),
            ),
            SizedBox(height: 20),
            // Show the export button only when bounding boxes are shown
            if (firststate)
              ElevatedButton(
                onPressed: exportToCSV,
                child: Text('Export to CSV'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.deepPurple, // Text color
                ),
              ),
            SizedBox(height: 20),
            Center(
              child: Visibility(
                visible: _imagePrediction != null,
                child: Text("$_imagePrediction"),
              ),
            ),
            // Button to click pic
            // ElevatedButton(
            //   onPressed: () {
            //     runObjectDetection();
            //   },
            //   child: const Icon(Icons.camera_alt_outlined),
            //   style: ElevatedButton.styleFrom(
            //     foregroundColor: Colors.white, backgroundColor: Colors.deepPurple, // text color
            //     shape: CircleBorder(), // circular button
            //     padding: EdgeInsets.all(16), // padding
            //   ),
            // )
          ],
        ),
      ),
    );
  }
}
