// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
//
// class ServerPage extends StatefulWidget {
//   @override
//   _ServerPageState createState() => _ServerPageState();
// }
//
// class _ServerPageState extends State<ServerPage> {
//   final ImagePicker _picker = ImagePicker();
//
//   Future<void> _uploadFile(XFile? file) async {
//     if (file == null) return;
//
//     var request = http.MultipartRequest('POST', Uri.parse('https://532e-14-139-174-50.ngrok-free.app/upload'));
//     request.files.add(await http.MultipartFile.fromPath('file', file.path));
//
//     var res = await request.send();
//     if (res.statusCode == 200) {
//       print('Upload successful');
//     } else {
//       print('Upload failed');
//     }
//   }
//
//   Future<void> _pickMedia({required bool isVideo}) async {
//     XFile? file;
//     if (isVideo) {
//       file = await _picker.pickVideo(source: ImageSource.gallery);
//     } else {
//       file = await _picker.pickImage(source: ImageSource.gallery);
//     }
//     _uploadFile(file);
//   }
//
//   Future<void> _showPickOptionsDialog(BuildContext context) {
//     return showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text("Choose option"),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 GestureDetector(
//                   child: Text("Image"),
//                   onTap: () {
//                     Navigator.of(context).pop();
//                     _pickMedia(isVideo: false);
//                   },
//                 ),
//                 Padding(padding: EdgeInsets.all(8.0)),
//                 GestureDetector(
//                   child: Text("Video"),
//                   onTap: () {
//                     Navigator.of(context).pop();
//                     _pickMedia(isVideo: true);
//                   },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Upload Image/Video'),
//       ),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () => _showPickOptionsDialog(context),
//           child: Text('Pick and Upload Image/Video'),
//         ),
//       ),
//     );
//   }
// }
//
// void main() => runApp(MaterialApp(home: ServerPage()));
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
  String? _mediaType; // New variable to store the media type
  String? _imageUrl; // URL for the image
  bool _isLoading = false; // To manage loading state
  Uint8List? imageData;

  @override
  void dispose() {
    _controller?.dispose(); // Dispose the video controller
    super.dispose();
  }

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

  // Future<void> _fetchMedia() async {
  //   var url = 'https://532e-14-139-174-50.ngrok-free.app/get-media';
  //   var response = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'});
  //   _mediaType = response.headers['content-type'];
  //
  //   if (_mediaType != null) {
  //     if (_mediaType!.startsWith('video/')) {
  //       _controller = VideoPlayerController.network(url)
  //         ..initialize().then((_) {
  //           setState(() {});
  //           _controller!.play(); // Play video after initialization
  //         });
  //     } else if (_mediaType!.startsWith('image/')) {
  //       _imageUrl = url; // Set image URL
  //       setState(() {});
  //     }
  //   }
  // }

  Future<void> _fetchMedia() async {
    var url = 'https://532e-14-139-174-50.ngrok-free.app/get-media';
    try {
      var response = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'});
      _mediaType = response.headers['content-type'];
      if (response.statusCode == 200) {
        if (_mediaType != null) {
          if (_mediaType!.startsWith('video/')) {
            _controller = VideoPlayerController.network(url)
              ..initialize().then((_) {
                setState(() {});
                _controller!.play(); // Play video after initialization
              });
          } else if (_mediaType!.startsWith('image/')) {
            setState(() {
              imageData = response.bodyBytes;
            });
          }
        }
        // setState(() {
        //   imageData = response.bodyBytes;
        // });
      } else {
        print('Failed to load media');
      }
    } catch (e) {
      print('Error fetching media: $e');
    }
  }

  Future<void> _pickMedia({required bool isVideo}) async {
    XFile? file;
    if (isVideo) {
      file = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      file = await _picker.pickImage(source: ImageSource.gallery);
    }
    _uploadFile(file);
  }

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
                    _pickMedia(isVideo: false);
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text("Video"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickMedia(isVideo: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Image/Video'),
      ),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_mediaType != null && _mediaType!.startsWith('image/')) ...[
              imageData != null ? Image.memory(imageData!) : Container(),
            ] else if (_mediaType != null && _mediaType!.startsWith('video/')) ...[
              _controller != null && _controller!.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
                  : Container(),
            ],
            ElevatedButton(
              onPressed: () => _showPickOptionsDialog(context),
              child: Text('Pick and Upload Image/Video'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() => runApp(MaterialApp(home: ServerPage()));
