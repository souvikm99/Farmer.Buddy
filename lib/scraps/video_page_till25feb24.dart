// //works fine, draw bboxes and shows class names and score, with recent yolov5 version
//
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_pytorch/flutter_pytorch.dart';
// import 'dart:async';
// import 'scraps/test_overlay.dart';
//
// import 'main.dart'; // Ensure this import points to your main.dart where 'cameras' list is defined
//
// class VideoPage extends StatefulWidget {
//   const VideoPage({super.key});
//
//   @override
//   State<VideoPage> createState() => _VideoPageState();
// }
//
// class _VideoPageState extends State<VideoPage> {
//   late CameraController cameraController;
//   CameraImage? imgCamera; // Made nullable
//   bool isWorking = false;
//   late ModelObjectDetection _objectModel;
//   List<Box> boxes = []; // Initialize as empty
//   final GlobalKey cameraPreviewKey = GlobalKey(); // GlobalKey for the camera preview
//
//
//   @override
//   void initState() {
//     super.initState();
//     loadModel().then((_) {
//       initCamera();
//     }).catchError((error) {
//       print("Error loading model: $error");
//     });
//   }
//
//   Future<void> loadModel() async {
//     String pathObjectDetectionModel = "assets/models/best_optimized.torchscript";
//     try {
//       _objectModel = await FlutterPytorch.loadObjectDetectionModel(
//           pathObjectDetectionModel, 14, 640, 640, labelPath: "assets/labels/lb2.txt");
//     } catch (e) {
//       print("Error loading model: $e");
//       rethrow; // Rethrow the error to catch it in initState
//     }
//   }
//
//   void initCamera() {
//     cameraController = CameraController(cameras![0], ResolutionPreset.high); // Set to a higher preset
//     cameraController.initialize().then((_) {
//       if (!mounted) {
//         return;
//       }
//       setState(() {
//         cameraController.startImageStream((imageFromStream) {
//           if (!isWorking) {
//             isWorking = true;
//             imgCamera = imageFromStream;
//             runObjectDetection();
//           }
//         });
//       });
//     }).catchError((error) {
//       print("Error initializing camera: $error");
//     });
//   }
//
//
//   Future<void> runObjectDetection() async {
//     if (imgCamera == null || !mounted) return; // Check if the widget is still mounted
//
//     // Obtain the RenderBox object
//     RenderBox? renderBox = cameraPreviewKey.currentContext?.findRenderObject() as RenderBox?;
//     // Now you can get the size of the CameraPreview
//     final previewSize = renderBox?.size;
//
//     // Continue with object detection...
//     final objDetect = await _objectModel.getImagePredictionFromBytesList(
//       imgCamera!.planes.map((plane) => plane.bytes).toList(),
//       imgCamera!.width,
//       imgCamera!.height,
//     );
//
//     // Ensure that the widget is still mounted before updating the state
//     if (mounted) {
//       setState(() {
//         // Update state here
//         boxes.clear();
//       });
//     }
//
//     // // Clear previous boxes
//     // setState(() {
//     //   boxes.clear();
//     // });
//
//     // Inside your loop where you process detections and create boxes
//     for (var element in objDetect) {
//       // Your existing logic to process detections...
//       print({
//         "score": element?.score,
//         "className": element?.className,
//         "class": element?.classIndex,
//         "rect": {
//           "left": element?.rect.left,
//           "top": element?.rect.top,
//           "width": element?.rect.width,
//           "height": element?.rect.height,
//           "right": element?.rect.right,
//           "bottom": element?.rect.bottom,
//         },
//       });
//
//       // Use the size of the CameraPreview for scaling
//       final scaleW = previewSize?.width ?? MediaQuery.of(context).size.width;
//       final scaleH = previewSize?.height ?? MediaQuery.of(context).size.height;
//
//       // Convert rect from model to camera preview coordinates
//       double left = element!.rect.left * scaleW;
//       double top = element.rect.top * scaleH;
//       double width = element.rect.width * scaleW;
//       double height = element.rect.height * scaleH;
//
//       // Add box with converted coordinates
//       // Ensure that the widget is still mounted before calling addBox
//       if (mounted) {
//         addBox(top, left, width, height, Colors.blue, element!.className.toString(), element!.score);
//       }
//     }
//
//     // Ready for next frame
//     isWorking = false;
//   }
//
//
//   @override
//   void dispose() {
//     // Dispose of camera controller
//     cameraController.stopImageStream();
//     cameraController.dispose();
//     super.dispose();
//   }
//
//   // @override
//   // Widget build(BuildContext context) {
//   //
//   //   return SafeArea(
//   //     child: Scaffold(
//   //       appBar: AppBar(title: const Text("OBJECT DETECTOR LIVE")),
//   //       backgroundColor: Colors.lightBlue,
//   //       body: Container(
//   //         margin: const EdgeInsets.only(top: 50),
//   //         color: Colors.black,
//   //         child: Stack(
//   //           children: [
//   //             Positioned(
//   //               top: 0.0,
//   //               left: 0.0,
//   //               right: 0.0,
//   //               bottom: 100.0, // Adjust based on your UI
//   //               child: cameraController.value.isInitialized
//   //                   ? AspectRatio(
//   //                 aspectRatio: cameraController.value.aspectRatio,
//   //                 child: CameraPreview(cameraController),
//   //               )
//   //                   : const Center(child: CircularProgressIndicator()),
//   //             ),
//   //             // Add additional UI elements or overlays here
//   //           ],
//   //         ),
//   //       ),
//   //     ),
//   //   );
//   // }
//
// // Updated addBox function to immediately reflect changes
//   // Updated addBox function to ensure widget is mounted before calling setState
//   void addBox(double top, double left, double width, double height, Color color, String className, double score) {
//     if (!mounted) return; // Check if the widget is still mounted
//     final box = Box(
//       top: top,
//       left: left,
//       width: width,
//       height: height,
//       color: color,
//       className: className,
//       score: score,
//     );
//     setState(() {
//       boxes.add(box);
//     });
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("OBJECT DETECTOR LIVE")),
//       backgroundColor: Colors.lightBlue,
//       body: SafeArea(
//         child: Stack(
//           children: <Widget>[
//             // Correct usage of CameraPreview with cameraController
//             CameraPreview(cameraController, key: cameraPreviewKey),
//             CustomPaint(
//               size: Size.infinite,
//               painter: BoxPainter(boxes: boxes),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
// }
//
// class Box {
//   final double top;
//   final double left;
//   final double width;
//   final double height;
//   final Color color;
//   final String className;
//   final double score;
//
//   Box({
//     required this.top,
//     required this.left,
//     required this.width,
//     required this.height,
//     required this.color,
//     required this.className,
//     required this.score,
//   });
// }
//
//
// class BoxPainter extends CustomPainter {
//   final List<Box> boxes;
//
//   BoxPainter({required this.boxes});
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.red // Example color for the box
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3.0;
//
//     final textPaint = Paint()
//       ..color = Colors.yellow // Example color for the text
//       ..style = PaintingStyle.fill;
//
//     for (var box in boxes) {
//       // Draw the box
//       canvas.drawRect(Rect.fromLTWH(box.left, box.top, box.width, box.height), paint);
//
//       // Prepare the text, converting score to percentage format here
//       final String displayText = '${box.className} ${(box.score * 100).toStringAsFixed(2)}%';
//       final textStyle = TextStyle(color: Colors.yellow, fontSize: 12,);
//       final textSpan = TextSpan(text: displayText, style: textStyle);
//       final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
//
//       // Layout and paint the text
//       textPainter.layout(minWidth: 0, maxWidth: size.width);
//       final offset = Offset(box.left, box.top - 15); // Adjust as needed
//       textPainter.paint(canvas, offset);
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
//
