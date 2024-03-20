import 'package:flutter/material.dart';
import 'package:object_detection/HomeScreen.dart';
import 'package:object_detection/server_page.dart';
import 'package:object_detection/test.dart';
import 'package:object_detection/video_page.dart';
import 'package:camera/camera.dart';
import 'package:object_detection/scraps/test_overlay.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBJECT DETECTOR yolov5',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        hintColor: Colors.deepPurpleAccent,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.deepPurple,
            textStyle: TextStyle(fontSize: 18),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const HomePage(),
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
        centerTitle: true,
        backgroundColor: Colors.deepPurple[400],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.deepPurple.shade200,
              Colors.deepPurple.shade500,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActionButton(context, 'Capture & Run', Icons.camera_alt, HomeScreen()),
              SizedBox(height: 20),
              _buildActionButton(context, 'Live Video', Icons.videocam, VideoPage()),
              SizedBox(height: 20),
              _buildActionButton(context, 'Server', Icons.web_rounded, ServerPage()),
              SizedBox(height: 20),
              _buildActionButton(context, 'Test', Icons.west, VideoExample()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String text, IconData icon, Widget destination) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 50), // Control the button width by adjusting padding
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(text),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 10,
        ).copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.deepPurple),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          overlayColor: MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) return Colors.deepPurple.shade700;
              return null; // Defer to the widget's default.
            },
          ),
          textStyle: MaterialStateProperty.all(TextStyle(fontSize: 18)),
          side: MaterialStateProperty.all(BorderSide(color: Colors.deepPurpleAccent, width: 1)),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ),
    );
  }
}
