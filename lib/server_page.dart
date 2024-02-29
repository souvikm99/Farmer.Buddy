import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:typed_data';

class ServerPage extends StatefulWidget {
  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _controller;
  String? _mediaType; // Variable to store the media type
  Uint8List? imageData; // Variable to store image data
  bool _isLoading = false; // Loading state
  bool _isPlaying = false; // Playing state

  @override
  void dispose() {
    _controller?.dispose(); // Dispose the video controller
    super.dispose();
  }

  // Function to upload file
  Future<void> _uploadFile(XFile? file) async {
    if (file == null) return;

    setState(() {
      _isLoading = true; // Set loading state
    });

    var request = http.MultipartRequest('POST', Uri.parse('https://532e-14-139-174-50.ngrok-free.app/upload'));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var res = await request.send();
    if (res.statusCode == 200) {
      print('Upload successful');
      await _fetchMedia(); // Fetch the media after successful upload
    } else {
      print('Upload failed');
    }

    setState(() {
      _isLoading = false; // Reset loading state
    });
  }

  // Function to fetch media from server
  Future<void> _fetchMedia() async {
    var url = 'https://532e-14-139-174-50.ngrok-free.app/get-media';
    try {
      var response = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'});
      _mediaType = response.headers['content-type'];
      if (response.statusCode == 200) {
        if (_mediaType != null) {
          if (_mediaType!.startsWith('video/')) {
            // If media is video, initialize video controller
            _controller = VideoPlayerController.network(url)
              ..initialize().then((_) {
                setState(() {});
                _controller!.play(); // Play video after initialization
              });
          } else if (_mediaType!.startsWith('image/')) {
            // If media is image, set image data
            setState(() {
              imageData = response.bodyBytes;
            });
          }
        }
      } else {
        print('Failed to load media');
      }
    } catch (e) {
      print('Error fetching media: $e');
    }
  }

  // Function to pick media from gallery
  Future<void> _pickMedia({required bool isVideo}) async {
    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      file = await _picker.pickImage(source: ImageSource.gallery);
    }
    _uploadFile(file); // Upload picked media
  }

  // Function to show dialog for choosing media option
  Future<void> _showPickOptionsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Choose option"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: Text("Image"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickMedia(isVideo: false); // Pick image
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text("Video"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickMedia(isVideo: true); // Pick video
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Function to play or pause video
  void _toggleVideoPlayback() {
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Image/Video'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator() // Show loading indicator
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_mediaType != null && _mediaType!.startsWith('image/')) ...[
              // If media is image, show image
              imageData != null ? Image.memory(imageData!) : Container(),
            ] else if (_mediaType != null && _mediaType!.startsWith('video/')) ...[
              // If media is video, show video player
              _controller != null && _controller!.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller!),
                    _buildPlaybackControls(),
                  ],
                ),
              )
                  : Container(),
            ],
            ElevatedButton(
              onPressed: () => _showPickOptionsDialog(context), // Show pick options dialog
              child: Text('Pick and Upload Image/Video'),
            ),
          ],
        ),
      ),
    );
  }

  // Function to build playback controls
  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _toggleVideoPlayback,
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
          Flexible(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: Colors.white,
                backgroundColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() => runApp(MaterialApp(home: ServerPage()));