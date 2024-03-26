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

  @override
  void initState() {
    super.initState();
    loadModel().then((_) {
      // Auto-start object detection after model is loaded
      runObjectDetection();
    });
  }

  Future<void> loadModel() async {
    String pathObjectDetectionModel = "assets/models/best_optimized.torchscript";
    try {
      _objectModel = await FlutterPytorch.loadObjectDetectionModel(
          pathObjectDetectionModel, 14, 640, 640,
          labelPath: "assets/labels/lb2.txt");
      print("Model loaded successfully");
    } catch (e) {
      print("Error loading model: $e");
      // Consider showing an error message to the user
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
  Future<void> runObjectDetection() async {
    if (_objectModel == null) {
      print("Model not loaded. Please load the model before running object detection.");
      return;
    }

    setState(() {
      firststate = false;
      message = false;
    });
    //pick an image
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    objDetect = (await _objectModel?.getImagePrediction(
        await File(image!.path).readAsBytes(),
        minimumScore: 0.1,
        IOUThershold: 0.3))!;
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
      _image = File(image!.path);
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
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                        Icon(Icons.menu, color: Colors.green), // Menu icon
                        Text(
                          'Farmer Buddy',
                          style: TextStyle(
                            color: Colors.green, // Adjust the color to match your brand color
                            fontWeight: FontWeight.bold,
                            fontSize: 24.0, // Adjust the font size to your preference
                          ),
                        ),
                        Icon(Icons.notifications, color: Colors.green), // Notifications icon
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 5.0, 0, 0), // Reduced top padding
                child: ListView(
                  children: <Widget>[
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
                                height: 160, // Set a fixed height for the scrollable container
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: uniqueObjectCounts.entries
                                        .map((entry) => CropCounter(crop: entry.key, count: entry.value))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 130, // Fixed height for the bar chart container
                              child: BarChartWidget(
                                data: uniqueObjectCounts, // You would pass the necessary data to the BarChartWidget
                              ),
                            ),
                            // Padding(
                            //   padding: const EdgeInsets.all(16.0),
                            //   child: Row(
                            //     mainAxisAlignment: MainAxisAlignment.spaceAround,
                            //     children: <Widget>[
                            //     ElevatedButton(
                            //                 onPressed: runObjectDetection, // Hook up the Run Again functionality
                            //                 child: Text('Run Again', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            //                 style: ElevatedButton.styleFrom(
                            //                   backgroundColor: Color(0xFFA3D79C),
                            //                   shape: RoundedRectangleBorder(
                            //                     borderRadius: BorderRadius.circular(15),
                            //                   ),
                            //                 ),
                            //               ),
                            //               ElevatedButton(
                            //                 onPressed: checkAndExportToCSV, // Hook up the Export CSV functionality
                            //                 child: Text('Export CSV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                            //                 style: ElevatedButton.styleFrom(
                            //                   backgroundColor: Color(0xFFEDAC4A),
                            //                   shape: RoundedRectangleBorder(
                            //                     borderRadius: BorderRadius.circular(15),
                            //                   ),
                            //                 ),
                            //               ),
                            //     ],
                            //   ),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: Container(
                  // padding: EdgeInsets.symmetric(vertical: 8), // Optional: for some internal padding around the buttons
                  decoration: BoxDecoration(
                    color: Colors.white, // Set the background color to white
                    borderRadius: BorderRadius.circular(0), // Optional: if you want the container to be rounded
                    // boxShadow: [ // Optional: if you want to add a shadow for better contrast
                    //   BoxShadow(
                    //     color: Colors.grey.withOpacity(0.5),
                    //     spreadRadius: 1,
                    //     blurRadius: 5,
                    //     offset: Offset(0, -1), // Changes position of shadow
                    //   ),
                    // ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: runObjectDetection, // Hook up the Run Again functionality
                        child: Text('Run Again', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFA3D79C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: checkAndExportToCSV, // Hook up the Export CSV functionality
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
                ),
              ),
            ),

          ],
        ),
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





