import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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


class MultImage extends StatefulWidget {
  @override
  _MultImageState createState() => _MultImageState();
}

class _MultImageState extends State<MultImage> {

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
  // Define a dictionary to store detection results and counts
  Map<String, int> detectionResults = {};

  GlobalKey _repaintBoundaryKey = GlobalKey();

  List<String> savedImagePaths = [];




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

    // Update dictionary with detection results
    objDetect.forEach((element) {
      if (element != null && element.className != null) {
        String className = element.className!;
        detectionResults[className] = (detectionResults[className] ?? 0) + 1;
      }
    });

    // Print the dictionary
    print('Detection Results: $detectionResults');

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
    saveDetectionImage();
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
    // Ensure permissions are granted
    await requestPermissions();

    // Initialize the CSV data with headers
    List<List<dynamic>> csvData = [
      ['Class', 'Count'],
    ];

    // Fill csvData with detectionResults
    detectionResults.forEach((key, value) {
      csvData.add([key, value]);
    });

    // Convert the data to CSV format
    String csv = const ListToCsvConverter().convert(csvData);

    try {
      // Get the temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/detection_counts.csv';

      // Save the CSV file at the path
      final File file = File(filePath);
      await file.writeAsString(csv);

      // Log the file path or share the file
      print('CSV file saved temporarily at $filePath');
      Share.shareFiles([filePath], text: 'Here is the exported CSV file.');
    } catch (e) {
      print('Error saving CSV file: $e');
    }
  }

  Future<void> saveDetectionImage() async {
    try {
      RenderObject? renderObject = _repaintBoundaryKey.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderRepaintBoundary) {
        ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          Uint8List pngBytes = byteData.buffer.asUint8List();
          final String formattedDateTime = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
          final directory = await getApplicationDocumentsDirectory();
          final imagePath = await File('${directory.path}/detection_image_$formattedDateTime.png').create();
          await imagePath.writeAsBytes(pngBytes);

          setState(() { // This ensures UI updates when a new image is saved
            savedImagePaths.add(imagePath.path);
          });

          print("Image saved to $imagePath");
        } else {
          print("Byte data is null");
        }
      } else {
        print("Context is null or RenderObject is not a RenderRepaintBoundary.");
      }
    } catch (e) {
      print("Error saving detection image: $e");
    }
  }




  Future<void> shareDetectionImage() async {
    try {
      RenderRepaintBoundary boundary =
      _repaintBoundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Get the current date and time
      final String formattedDateTime = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');


      final directory = await getApplicationDocumentsDirectory();
      // Append the date and time to the filename
      final imagePath = await File('${directory.path}/detection_image_$formattedDateTime.jpg').create();
      await imagePath.writeAsBytes(pngBytes);



      Share.shareFiles([imagePath.path], text: 'Check out these object detection results!');
    } catch (e) {
      print("Error sharing detection image: $e");
    }
  }

  Future<Size> _getImageSize(File imageFile) async {
    var decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
    return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
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
            // SafeArea(
            //   child: Padding(
            //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            //     child: Material(
            //       elevation: 0.1,
            //       color: Color(0xFFF9FAF2),
            //       borderRadius: BorderRadius.circular(5.0),
            //       child: Container(
            //         padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            //         child: Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //           children: <Widget>[
            //             Icon(Icons.menu, color: Colors.green), // Menu icon
            //             Text(
            //               'Farmer Buddy',
            //               style: TextStyle(
            //                 color: Colors.green, // Adjust the color to match your brand color
            //                 fontWeight: FontWeight.bold,
            //                 fontSize: 24.0, // Adjust the font size to your preference
            //               ),
            //             ),
            //             Icon(Icons.notifications, color: Colors.green), // Notifications icon
            //           ],
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
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
                          topLeft: Radius.circular(10.0),
                          topRight: Radius.circular(10.0),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10.0),
                          topRight: Radius.circular(10.0),
                        ),
                        child: Column(
                          children: [
                            _repaintBoundaryKey != null && _image != null
                                ? RepaintBoundary(
                              key: _repaintBoundaryKey,
                              child: Container(
                                decoration: BoxDecoration(
                                  // color: Colors.white, // Container background color
                                  borderRadius: BorderRadius.all(Radius.circular(10.0)), // This is necessary if you have a border or shadow
                                ),
                                child: _objectModel!.renderBoxesOnImage(_image!, objDetect),
                                width: double.infinity,
                                height: 230,
                              ),
                            )

                                : Image.asset(
                              'assets/loading_icon_green_banner.png',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 230,
                            ),

                            Container(
                              height: 50, // Adjust the container height as needed
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: savedImagePaths.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 5.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10.0), // Rounded corners
                                      child: GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return Dialog(
                                                backgroundColor: Colors.transparent, // Makes background transparent
                                                child: FutureBuilder(
                                                  future: _getImageSize(File(savedImagePaths[index])),
                                                  builder: (BuildContext context, AsyncSnapshot<Size> snapshot) {
                                                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                                      // Calculate the best width and height for the image based on screen size
                                                      var screenWidth = MediaQuery.of(context).size.width;
                                                      var screenHeight = MediaQuery.of(context).size.height;
                                                      var imageSize = snapshot.data!;
                                                      var widthRatio = screenWidth / imageSize.width;
                                                      var heightRatio = screenHeight / imageSize.height;
                                                      var bestRatio = widthRatio < heightRatio ? widthRatio : heightRatio;
                                                      var displayWidth = imageSize.width * bestRatio;
                                                      var displayHeight = imageSize.height * bestRatio;

                                                      return Container(
                                                        width: displayWidth,
                                                        height: displayHeight,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(20), // Rounded corners for the dialog
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(15.0), // Rounded corners for the image
                                                          child: Image.file(
                                                            File(savedImagePaths[index]),
                                                            width: displayWidth,
                                                            height: displayHeight,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      );
                                                    } else {
                                                      return CircularProgressIndicator(); // Show loading indicator while waiting
                                                    }
                                                  },
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: 50, // Adjust the image width as needed
                                          height: 50, // Adjust the image height as needed
                                          child: Image.file(
                                            File(savedImagePaths[index]),
                                            fit: BoxFit.cover, // Ensures the image covers the container
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),



                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5.0, 0, 5.0),
                              child: Container(
                                height: 160,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: detectionResults.entries.map((entry) =>
                                        CropCounter(crop: entry.key, count: entry.value)).toList(),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 130,
                              child: BarChartWidget(
                                data: detectionResults,
                              ),
                            ),

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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: runObjectDetection,
                        child: Text('Add Images', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF7DC11),
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
                      ElevatedButton(
                        onPressed: shareDetectionImage,
                        child: Icon(Icons.share),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF66ff99),
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
              width: 5, // Adjusted bar width for a sleeker look
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
                    child: Text(text, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 4)), // Smaller font size
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







