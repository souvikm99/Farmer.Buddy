import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  runApp(TestState());
}

class TestState extends StatefulWidget {
  @override
  _TestStateState createState() => _TestStateState();
}

class _TestStateState extends State<TestState> {
  Uint8List? imageData;
  VideoPlayerController? videoController;

  @override
  void initState() {
    super.initState();
    // Initial fetch for the media
    fetchMedia();
  }

  Future<void> fetchMedia() async {
    // URL of your Flask server
    final url = Uri.parse('https://532e-14-139-174-50.ngrok-free.app/get-media');
    try {
      // Attempt to fetch the media
      var response = await http.get(url);
      if (response.statusCode == 200) {
        // Here you'd need logic to determine if the response is an image or a video
        // For simplicity, let's assume it's always an image for this example
        setState(() {
          imageData = response.bodyBytes;
          // If it's a video, you'd initialize the videoController here
          // and set imageData to null
        });
      } else {
        print('Failed to load media');
      }
    } catch (e) {
      print('Error fetching media: $e');
    }
  }

  Widget buildMedia() {
    if (imageData != null) {
      return Image.memory(imageData!);
    } else if (videoController != null && videoController!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: videoController!.value.aspectRatio,
        child: VideoPlayer(videoController!),
      );
    } else {
      return CircularProgressIndicator(); // Show loading indicator while media is being fetched
    }
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Fetch Media'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              buildMedia(),
              ElevatedButton(
                onPressed: fetchMedia, // Refresh media source from the server
                child: Text('Fetch Media from Server'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
