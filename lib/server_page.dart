import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:typed_data';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class ServerPage extends StatefulWidget {
  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? imageData;
  bool _isLoading = false;
  VlcPlayerController? _vlcPlayerController;
  String? _mediaType;
  bool _isPlaying = false;
  double _sliderValue = 0.0;
  Duration _videoDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  Timer? _timer;
  String _data = "Press the button to fetch data";
  String api_name = "http://192.168.1.23:5050";



  @override
  void dispose() {
    // _controller?.dispose(); // Dispose the video controller
    _vlcPlayerController?.dispose(); // Dispose the VLC video controller
    _timer?.cancel();
    super.dispose();
  }

  // Function to upload file
  Future<void> _uploadFile(XFile? file) async {
    if (file == null) return;

    setState(() {
      _isLoading = true; // Set loading state
    });

    var request = http.MultipartRequest('POST', Uri.parse(api_name+'/upload'));
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
    var url = api_name+'/get-media';
    try {
      var response = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'});
      _mediaType = response.headers['content-type'];
      if (response.statusCode == 200) {
        if (_mediaType != null) {
          if (_mediaType!.startsWith('video/')) {
            // Initialize VLC video controller if media is video
            _vlcPlayerController = VlcPlayerController.network(
              url,
              autoPlay: true,
              hwAcc: HwAcc.full,
              options: VlcPlayerOptions(),
            )..addListener(() {
              final state = _vlcPlayerController!.value;

              // Update UI based on playback state
              _updateState();

              // Check for the video ended event
              if (state.playingState == PlayingState.ended) {
                // Video playback is complete
                setState(() {
                  _isPlaying = true;
                  // Reset the video position to the start for a replay option
                  // _vlcPlayerController!.setTime(0);
                  // // Optionally, automatically start playing again for a replay
                  _vlcPlayerController!.play();
                });
              }
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




  Future<String> _fetchCounts() async {
    final response = await http.get(
      Uri.parse(api_name+'/get-counts'),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success']) {
        return responseData['countsData'];
      } else {
        return 'Failed to load counts data: ${responseData['error']}';
      }
    } else {
      return 'Failed to load counts data.';
    }
  }

  fetchData() async {
    try {
      final response = await http.get(Uri.parse(api_name+'/get-counts'));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final String data = jsonData['data'] ?? "No data available"; // Provide a fallback value
        setState(() {
          _data = data; // _data should be initialized to a non-null String
        });
      } else {
        setState(() {
          _data = "Error fetching data.";
        });
      }
    } catch (e) {
      setState(() {
        _data = "Exception: $e"; // Ensure _data is never set to null
      });
    }
  }


  // Function to pick media from gallery
  Future<void> _pickMedia({required bool isVideo, required bool isCapture}) async {
    XFile? file;
    if (isCapture) {
      file = isVideo
          ? await _picker.pickVideo(source: ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.camera);
    } else {
      file = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery);
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
                  child: Text("Upload Image"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickMedia(isVideo: false, isCapture: false);
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text("Upload Video"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickMedia(isVideo: true, isCapture: false);
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text("Capture Image"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickMedia(isVideo: false, isCapture: true);
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text("Capture Video"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickMedia(isVideo: true, isCapture: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCountsData(BuildContext context) async {
    await fetchData(); // This will update _data with the fetched data
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Counts Data"),
          content: SingleChildScrollView(
            child: Text(_data), // Display the data fetched by fetchData
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }



  void _updateState() async {
    if (_vlcPlayerController == null) return;
    var position = await _vlcPlayerController!.getPosition();
    setState(() {
      _currentPosition = position;
      _videoDuration = _vlcPlayerController!.value.duration;
      _sliderValue = _currentPosition.inMilliseconds.toDouble();
      _isPlaying = _vlcPlayerController!.value.isPlaying;
    });
  }

  void _onSliderChange(double value) {
    final position = Duration(milliseconds: value.toInt());
    _vlcPlayerController?.setTime(position.inMilliseconds);
    setState(() {
      _sliderValue = value;
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
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_mediaType != null && _mediaType!.startsWith('image/'))
              imageData != null ? Image.memory(imageData!) : Container(),
            if (_mediaType != null && _mediaType!.startsWith('video/'))
              _vlcPlayerController != null
                  ? Column(
                children: [
                  VlcPlayer(
                    controller: _vlcPlayerController!,
                    aspectRatio: 16 / 9,
                    placeholder: Center(child: CircularProgressIndicator()),
                  ),
                  // Slider(
                  //   min: 0,
                  //   max: _videoDuration.inMilliseconds.toDouble(),
                  //   value: _sliderValue.clamp(0, _videoDuration.inMilliseconds.toDouble()),
                  //   onChanged: _onSliderChange,
                  // ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _togglePlayPause,
                  ),
                ],
              )
                  : Container(),
            ElevatedButton(
              onPressed: () => _showPickOptionsDialog(context),
              child: Text('Pick and Upload Image/Video'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showCountsData(context),
              child: Text('Show Counts Data'),
            ),
          ],
        ),
      ),
    );
  }

  void _togglePlayPause() async {
    if (_vlcPlayerController != null) {
      final isPlaying = _vlcPlayerController!.value.isPlaying;

      if (isPlaying) {
        // If the video is currently playing, pause it.
        await _vlcPlayerController!.pause();
        setState(() => _isPlaying = false);
      } else {
        // Check if the video has ended.
        final currentPosition = await _vlcPlayerController!.getPosition();
        final isVideoEnded = currentPosition >= _videoDuration || currentPosition == Duration.zero;

        if (isVideoEnded || !_isPlaying) {
          // If the video ended, seek to the beginning and play again.
          await _vlcPlayerController!.setTime(0); // Seek to the beginning of the video
          await _vlcPlayerController!.play(); // Start playing the video
          setState(() {
            _isPlaying = true;
            _sliderValue = 0.0; // Reset the slider to the start
          });
        } else {
          // If the video is paused, just play it.
          await _vlcPlayerController!.play();
          setState(() => _isPlaying = true);
        }
      }
    }
  }





}

void main() => runApp(MaterialApp(home: ServerPage()));