import 'package:flutter/material.dart';
import 'package:object_detection/HomeScreen.dart';
import 'package:object_detection/scraps/test_overlay.dart';
import 'package:object_detection/video_page.dart'; // Import the NewPage
import 'package:camera/camera.dart';

List<CameraDescription>? cameras;

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBJECT DETECTOR yolov5',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(), // Use HomePage instead of HomeScreen
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YOLOv5 OBJ Detector'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              },
              child: Text('Capture & Run'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Get the camera and navigate to the VideoPage
                // final camera = await getCamera();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VideoPage()),
                );
              },
              child: Text('Live Video'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Get the camera and navigate to the VideoPage
                // final camera = await getCamera();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TakePictureScreen(camera: cameras!.first)),
                );
              },
              child: Text('Test'),
            ),
          ],
        ),
      ),
    );
  }
}
