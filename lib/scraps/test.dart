// import 'package:flutter/foundation.dart';
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
//   CameraImage? imgCamera;
//   bool isWorking = false;
//   late ModelObjectDetection _objectModel;
//   List<Box> boxes = [];
//   final GlobalKey cameraPreviewKey = GlobalKey();
//   int frameSkipCount = 0; // Skip processing some frames to reduce load
//   Timer? _debounce;
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
//       rethrow;
//     }
//   }
//
//   void initCamera() {
//     cameraController = CameraController(cameras![0], ResolutionPreset.medium);
//     cameraController.initialize().then((_) {
//       if (!mounted) {
//         return;
//       }
//       setState(() {
//         cameraController.startImageStream((imageFromStream) {
//           if (!isWorking && frameSkipCount++ % 5 == 0) {
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
//   Future<void> runObjectDetection() async {
//     if (imgCamera == null || !mounted) return;
//
//     final previewSize = cameraPreviewKey.currentContext?.findRenderObject()?.semanticBounds.size;
//
//     final objDetect = await _objectModel.getImagePredictionFromBytesList(
//       imgCamera!.planes.map((plane) => plane.bytes).toList(),
//       imgCamera!.width,
//       imgCamera!.height,
//     );
//
//     List<Box> newBoxes = [];
// // Inside your loop where you process detections and create boxes
//     for (var element in objDetect) {
//       final scaleW = previewSize?.width ?? MediaQuery.of(context).size.width;
//       final scaleH = previewSize?.height ?? MediaQuery.of(context).size.height;
//
//       double left = element!.rect.left * scaleW;
//       double top = element.rect.top * scaleH;
//       double width = element.rect.width * scaleW;
//       double height = element.rect.height * scaleH;
//
//       // Provide a fallback value for className if it's null
//       String className = element.className ?? "Unknown";
//
//       newBoxes.add(Box(
//         top: top,
//         left: left,
//         width: width,
//         height: height,
//         color: Colors.blue,
//         className: className, // Now guaranteed to be non-null
//         score: element.score,
//       ));
//     }
//
//
//     updateBoxes(newBoxes);
//     isWorking = false;
//   }
//
//   void updateBoxes(List<Box> newBoxes) {
//     if (_debounce?.isActive ?? false) _debounce!.cancel();
//     _debounce = Timer(const Duration(milliseconds: 100), () {
//       if (mounted) {
//         setState(() {
//           boxes = newBoxes;
//         });
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     cameraController.stopImageStream();
//     cameraController.dispose();
//     _debounce?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("OBJECT DETECTOR LIVE")),
//       backgroundColor: Colors.lightBlue,
//       body: SafeArea(
//         child: Stack(
//           children: <Widget>[
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
// class BoxPainter extends CustomPainter {
//   final List<Box> boxes;
//
//   BoxPainter({required this.boxes});
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.red
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 3.0;
//
//     for (var box in boxes) {
//       canvas.drawRect(Rect.fromLTWH(box.left, box.top, box.width, box.height), paint);
//
//       final String displayText = '${box.className} ${(box.score * 100).toStringAsFixed(2)}%';
//       final textStyle = TextStyle(color: Colors.yellow, fontSize: 12);
//       final textSpan = TextSpan(text: displayText, style: textStyle);
//       final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
//
//       textPainter.layout(minWidth: 0, maxWidth: size.width);
//       final offset = Offset(box.left, box.top - 15);
//       textPainter.paint(canvas, offset);
//     }
//   }
//
//   @override
//   bool shouldRepaint(BoxPainter oldDelegate) => !listEquals(oldDelegate.boxes, boxes);
// }
