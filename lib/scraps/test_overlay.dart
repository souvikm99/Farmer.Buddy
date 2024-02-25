import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

Future<void> Videomain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(camera: firstCamera),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({required this.camera, Key? key}) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<Box> boxes = []; // Initialize as empty

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium,);
    _initializeControllerFuture = _controller.initialize();
    addBox(50, 50, 150, 150, Colors.blue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Function to add a box
  void addBox(double top, double left, double width, double height, Color color) {
    setState(() {
      boxes.add(Box(top: top, left: left, width: width, height: height, color: color));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: <Widget>[
                CameraPreview(_controller),
                ...boxes.map((box) => Positioned(
                  top: box.top,
                  left: box.left,
                  child: Container(
                    width: box.width,
                    height: box.height,
                    decoration: BoxDecoration(
                      border: Border.all(color: box.color, width: 2),
                    ),
                  ),
                )).toList(),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Example use case: Add a new box with sample parameters
      //     addBox(50, 50, 150, 150, Colors.blue);
      //   },
      //   child: Icon(Icons.add),
      // ),
    );
  }
}

class Box {
  final double top;
  final double left;
  final double width;
  final double height;
  final Color color;

  Box({required this.top, required this.left, required this.width, required this.height, required this.color});
}
