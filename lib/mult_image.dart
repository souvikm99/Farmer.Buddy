import 'dart:convert';
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
import 'package:http/http.dart' as http;

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
  String? selectedModel; // Current selected model
  Map<String, Map<String, int>> imageDetectionResults = {};
  String processingTime = "No image has been processed";
  Map<String, File> _images = {};
  List<String> _fileNames = [];
  String? _selectedFile;
  bool _isLoading = true;
  String? _error;
  Set<String> _downloadedFiles = Set<String>();
  // Update models dictionary to include label path
  final Map<String, ModelInfo> models = {
    "AppleBananaOrange.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange"),
    "AppleBananaOrangeS10p.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange 10p"),
    "AppleBananaOrange_new.torchscript": ModelInfo(classNumber: 3, labelPath: "assets/labels/AppleBananaOrange.txt", name: "Apple Banana Orange New"),
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
    _fetchFileNames();
    selectedModel = models.keys.first;
    loadModel(selectedModel).then((_) {
      if (_objectModel == null) {
        showDialogWithMessage("Failed to load the model.");
      } else {
        // runObjectDetection();
      }
    });
  }

  Future<void> _fetchFileNames() async {
    try {
      final response = await http.get(Uri.parse('https://above-ladybug-hopeful.ngrok-free.app//files'));
      if (response.statusCode == 200) {
        setState(() {
          _fileNames = List<String>.from(json.decode(response.body));
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load files');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadFile(String fileName) async {
    try {
      // Prepare the file URL and get the document directory
      String fileUrl = 'https://above-ladybug-hopeful.ngrok-free.app/files/$fileName';
      Directory docDir = await getApplicationDocumentsDirectory();
      String filePath = '${docDir.path}/$fileName';

      // Start downloading the file
      var response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes); // Write the bytes to the file in the document directory
        setState(() {
          _downloadedFiles.add(fileName);
        });
        _showDownloadSuccessDialog(fileName);
        print("File downloaded to the document directory: $filePath");  // Print the file path
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _showDownloadSuccessDialog(String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Download Success"),
        content: Text("File '$fileName' has been downloaded successfully."),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Error"),
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

  Future<void> requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }


  // Future<XFile?> _pickImage() async {
  //   final source = await _showImageSourceDialog();
  //   if (source == null) return null;
  //   return await _picker.pickImage(source: source);
  // }

  Future<void> pickAndProcessImages() async {
    ImageSource? source = await _showImageSourceDialog();
    if (source == null) {
      showDialogWithMessage("No source selected.");
      return;
    }

    if (source == ImageSource.gallery) {
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images == null || images.isEmpty) {
        showDialogWithMessage("No images selected.");
        return;
      }
      for (var image in images) {
        await runObjectDetection(File(image.path));
      }
    } else if (source == ImageSource.camera) {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        showDialogWithMessage("No image selected.");
        return;
      }
      await runObjectDetection(File(image.path));
    }
  }


  Future<void> runObjectDetection(File image) async {
    if (_objectModel == null) {
      showDialogWithMessage("Model is not loaded. Please load a model first.");
      return;
    }

    var imageData = await image.readAsBytes();
    Stopwatch stopwatch = Stopwatch()..start();
    try {
      objDetect = await _objectModel!.getImagePrediction(imageData, minimumScore: 0.5, IOUThershold: 0.4, boxesLimit: 100);
      stopwatch.stop();

      objDetect.forEach((element) {
        if (element != null && element.className != null) {
          String className = element.className!;
          detectionResults[className] = (detectionResults[className] ?? 0) + 1;
        }
      });

      countUniqueObjects(); // Count unique objects after detection

      await saveDetectionImage();  // Modify this function as needed to handle detection results

      scheduleTimeout(5 * 1000);

      setState(() {
        _image = File(image.path);
        processingTime = "Processed in: ${stopwatch.elapsedMilliseconds}ms";
      });
    } catch (e) {
      showDialogWithMessage("Failed to run object detection: $e");
    }
  }


  Future<void> saveDetectionImage() async {
    // This should include logic to save the detection results if necessary
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

              Map<String, int> currentImageResults = {};
              objDetect.forEach((element) {
                if (element != null && element.className != null) {
                  currentImageResults[element.className!] = (currentImageResults[element.className!] ?? 0) + 1;
                }
              });

              // Save current image detection results
              imageDetectionResults[imagePath.path] = currentImageResults;

              print("PAST IMAGES : $imageDetectionResults");

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



      Share.shareFiles([imagePath.path], text: 'Check out these crop counting results!');
    } catch (e) {
      print("Error sharing detection image: $e");
    }
  }

  Future<Size> _getImageSize(File imageFile) async {
    var decodedImage = await decodeImageFromList(imageFile.readAsBytesSync());
    return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
  }

// Helper method to format detection results into a string.
  String _formatDetectionResults() {
    if (objDetect.isEmpty) {
      return "No detections";
    }
    Map<String, int> counts = {};
    for (var detection in objDetect) {
      if (detection != null && detection.className != null) {
        counts[detection.className!] = (counts[detection.className!] ?? 0) + 1;
      }
    }
    return counts.entries.map((e) => "${e.key}: ${e.value}").join(", ");
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
                      _image != null
                          ? RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(Radius.circular(10.0)),
                              ),
                              width: double.infinity,
                              height: 250,
                              child: _objectModel!.renderBoxesOnImage(_image!, objDetect),
                            ),
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                color: Colors.black.withOpacity(0.5), // Semi-transparent background for the text
                                child: Text(
                                  _formatDetectionResults(), // Dynamic detection results text
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8, // Adjust font size as needed
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          : Image.asset(
                        'assets/loading_icon_green_banner.png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 250,
                      ),
                      Container(
                        height: 200, // Set the fixed height here
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Container(
                                height: 50, // Adjust the container height as needed
                                padding: EdgeInsets.symmetric(vertical: 5),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: savedImagePaths.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () => _showImageDialog(context, savedImagePaths[index]),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 5.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10.0), // Rounded corners
                                          child: Image.file(
                                            File(savedImagePaths[index]),
                                            width: 50, // Adjust the image width as needed
                                            height: 50, // Adjust the image height as needed
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0,0.0, 0, 5.0),
                                child: Container(
                                  height: 100,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: detectionResults.entries.map((entry) =>
                                          CropCounter(crop: entry.key, count: entry.value)).toList(),
                                    ),
                                  ),
                                ),
                              ),
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
                                          dropdownColor: Color(0xffF3F3F3),
                                          onChanged: (String? newValue) {
                                            setState(() {
                                              selectedModel = newValue;
                                              loadModel(selectedModel).then((_) {});
                                            });
                                          },
                                          items: models.entries.map((MapEntry<String, ModelInfo> entry) {
                                            return DropdownMenuItem<String>(
                                              value: entry.key,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 10),
                                                child: Text(entry.value.name),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5), // Padding inside the container
                                      decoration: BoxDecoration(
                                        color: Colors.white, // Background color
                                        borderRadius: BorderRadius.circular(10), // Rounded corners
                                        border: Border.all(color: Colors.blueAccent), // Border color and width
                                      ),
                                      child: DropdownButton<String>(
                                        value: _selectedFile,
                                        isExpanded: true, // Ensures the dropdown takes the full width of the container
                                        hint: Text('Select a file'),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedFile = newValue;
                                          });
                                        },
                                        items: _fileNames.map<DropdownMenuItem<String>>((String fileName) {
                                          return DropdownMenuItem<String>(
                                            value: fileName,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(fileName, overflow: TextOverflow.ellipsis)), // Ensure text does not overflow
                                                if (!_downloadedFiles.contains(fileName))
                                                  IconButton(
                                                    icon: Icon(Icons.download_rounded),
                                                    onPressed: () {
                                                      _downloadFile(fileName);
                                                      Navigator.of(context).pop(); // Optionally close the dropdown after clicking
                                                    },
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        underline: Container(height: 0), // Remove underline by setting it to a container with height 0
                                      ),
                                    )

                                  ],
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
            ],
          ),
          // Fixed bottom container
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
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5.0),
                      height: 130.0,
                      child: BarChartWidget(data: detectionResults),
                    ),

                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          processingTime,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),


                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          onPressed: pickAndProcessImages,//runObjectDetection,
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent, // Makes background transparent
          child: FutureBuilder(
            future: _getImageSize(File(imagePath)),
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

                // Fetch detection results for the current image
                Map<String, int>? detections = imageDetectionResults[imagePath];
                String detectionText = detections?.entries.map((e) => "${e.key}: ${e.value}").join(", ") ?? "No detections";

                return Container(
                  width: displayWidth,
                  height: displayHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20), // Rounded corners for the dialog
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15.0), // Rounded corners for the image
                        child: Image.file(
                          File(imagePath),
                          width: displayWidth,
                          height: displayHeight,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: Colors.black.withOpacity(0.5), // Semi-transparent background for the text
                          // child: Text(
                          //   detectionText, // Dynamic detection results text
                          //   style: TextStyle(
                          //     color: Colors.white,
                          //     fontSize: 10, // Adjust font size as needed
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
                        ),
                      ),
                    ],
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
  }


}


class CropCounter extends StatelessWidget {
  final String crop;
  final int count;

  CropCounter({required this.crop, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
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


// Define a ModelInfo class to store model related information
// Define a ModelInfo class to store model related information
class ModelInfo {
  final int classNumber;
  final String labelPath;
  final String name; // New property for display name

  ModelInfo({required this.classNumber, required this.labelPath, required this.name});
}



