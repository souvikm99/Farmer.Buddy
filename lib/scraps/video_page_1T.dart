// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_pytorch/flutter_pytorch.dart';
// import 'dart:async';
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
//     String pathObjectDetectionModel = "assets/models/best_yolov5l.torchscript";
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
//     cameraController = CameraController(cameras![0], ResolutionPreset.medium);
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
//   Future<void> runObjectDetection() async {
//     if (imgCamera == null) return;
//
//     final objDetect = await _objectModel.getImagePredictionFromBytesList(
//       imgCamera!.planes.map((plane) => plane.bytes).toList(),
//       imgCamera!.width,
//       imgCamera!.height,
//     );
//
//     // Log detection results
//     for (var element in objDetect) {
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
//     }
//
//     // Ensuring we can process the next frame
//     isWorking = false;
//   }
//
//   @override
//   void dispose() {
//     cameraController.dispose(); // Ensure proper disposal
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     return SafeArea(
//       child: Scaffold(
//         appBar: AppBar(title: const Text("OBJECT DETECTOR LIVE")),
//         backgroundColor: Colors.lightBlue,
//         body: Container(
//           margin: const EdgeInsets.only(top: 50),
//           color: Colors.black,
//           child: Stack(
//             children: [
//               Positioned(
//                 top: 0.0,
//                 left: 0.0,
//                 right: 0.0,
//                 bottom: 100.0, // Adjust based on your UI
//                 child: cameraController.value.isInitialized
//                     ? AspectRatio(
//                   aspectRatio: cameraController.value.aspectRatio,
//                   child: CameraPreview(cameraController),
//                 )
//                     : const Center(child: CircularProgressIndicator()),
//               ),
//               // Add additional UI elements or overlays here
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// ################################################################
// ################################################################

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
//     String pathObjectDetectionModel = "assets/models/best_yolov5l.torchscript";
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
//     cameraController = CameraController(cameras![0], ResolutionPreset.medium);
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
//   Future<void> runObjectDetection() async {
//     if (imgCamera == null) return;
//
//     final objDetect = await _objectModel.getImagePredictionFromBytesList(
//       imgCamera!.planes.map((plane) => plane.bytes).toList(),
//       imgCamera!.width,
//       imgCamera!.height,
//     );
//
//     // Clear previous boxes
//     setState(() {
//       boxes.clear();
//     });
//
//     // Process each detection
//     for (var element in objDetect) {
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
//       // Convert normalized coordinates to screen dimensions
//       final screenSize = MediaQuery.of(context).size;
//       final screenH = screenSize.height;
//       final screenW = screenSize.width;
//       final previewH = screenH; // Adjust these based on your actual preview size
//       final previewW = screenW; // Adjust these based on your actual preview size
//
//       // Assuming the camera preview is full screen, adjust if it's not
//       double scaleW, scaleH;
//       scaleW = previewW;
//       scaleH = previewH;
//
//       // Convert rect from model to screen coordinates
//       double left = element!.rect.left * scaleW;
//       double top = element.rect.top * scaleH;
//       double width = element.rect.width * scaleW;
//       double height = element.rect.height * scaleH;
//
//       // Add box with converted coordinates
//       addBox(top, left, width, height, Colors.blue);
//     }
//
//     // Ready for next frame
//     isWorking = false;
//   }
//
//   @override
//   void dispose() {
//     cameraController.dispose(); // Ensure proper disposal
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
//   void addBox(double top, double left, double width, double height, Color color) {
//     final box = Box(top: top, left: left, width: width, height: height, color: color);
//     setState(() {
//       boxes.add(box);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("OBJECT DETECTOR LIVE")),
//       backgroundColor: Colors.lightBlue,
//       body: Container(
//         margin: const EdgeInsets.only(top: 50),
//         color: Colors.black,
//         child: Stack(
//           children: <Widget>[
//             CameraPreview(cameraController),
//             ...boxes.map((box) => Positioned(
//               top: box.top,
//               left: box.left,
//               child: Container(
//                 width: box.width,
//                 height: box.height,
//                 decoration: BoxDecoration(
//                   border: Border.all(color: box.color, width: 2),
//                 ),
//               ),
//             )).toList(),
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
//
//   Box({required this.top, required this.left, required this.width, required this.height, required this.color});
// }