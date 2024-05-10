import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path/path.dart' as path; // Make sure to import the 'path' package



void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // This binds the framework to Flutter engine
  await FlutterDownloader.initialize(
      debug: true // This is for debug logging, set it to false for production builds.
  );
  runApp(MaterialApp(home: ServerPage()));
}

class ServerPage extends StatefulWidget {
  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;
  String? _imageUrl;
  String? _message;
  String? _timeelpsd;
  String _selectedServerUrl = '';
  bool _compressVideo = false;  // Default to not compressing
  final FlutterFFmpeg _ffmpeg = FlutterFFmpeg();


  // Define your server options
  final List<ServerOption> serverOptions = [
    ServerOption(url: 'https://jackal-absolute-firefly.ngrok-free.app', name: 'MLG-NG'),
    ServerOption(url: 'https://souvikmallick.loca.lt', name: 'MLG-LOCA'),
    ServerOption(url: 'https://above-ladybug-hopeful.ngrok-free.app/', name: 'D3-LAB-NG'),
    ServerOption(url: 'https://www.creds.iitpkd.ac.in/', name: 'CREDS'),


    // Add more server options as needed
  ];


  @override
  void initState() {
    super.initState();
    // Set default selected server
    _selectedServerUrl = serverOptions.first.url;
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Container(
              height: 100, // Maintain the height of the container
              child: GridView.count(
                crossAxisCount: 4, // Number of columns
                crossAxisSpacing: 0, // Further reduced horizontal space between items
                mainAxisSpacing: 0, // Further reduced vertical space between items
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 5), // Reduced overall padding
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.photo_library, size: 45, color: Colors.green), // Slightly smaller icon size
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickMediaFromGallery(ImageSource.gallery, 'image');
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.photo_camera, size: 45, color: Colors.blueAccent), // Slightly smaller icon size
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickMediaFromGallery(ImageSource.camera, 'image');
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.video_library, size: 45, color: Colors.green), // Slightly smaller icon size
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickMediaFromGallery(ImageSource.gallery, 'video');
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.videocam, size: 45, color: Colors.blueAccent), // Slightly smaller icon size
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickMediaFromGallery(ImageSource.camera, 'video');
                    },
                  ),
                ],
              ),
            ),
          );
        }
    );
  }



  Future<void> _pickMediaFromGallery(ImageSource source, String mediaType) async {
    XFile? mediaFile;
    try {
      mediaFile = mediaType == 'image'
          ? await _picker.pickImage(source: source)
          : await _picker.pickVideo(source: source);
    } catch (e) {
      print('Failed to pick media: $e');
      return;
    }

    if (mediaFile != null) {
      _uploadFile(mediaFile);
    }
  }

  // Future<void> _uploadFile(XFile? file) async {
  //   if (file == null) return;
  //
  //   print('C O M P R E S S : $_compressVideo');
  //   if (_compressVideo) {
  //     // Start uploading message
  //     setState(() {
  //       _message = "Preparing upload...";
  //     });
  //
  //     // Check if the file is a video and compress it
  //     if (file.path.endsWith('.mp4') || file.path.endsWith('.avi')) {
  //       setState(() {
  //         _message = "Compressing video...";
  //       });
  //
  //       final MediaInfo? compressedVideo = await VideoCompress.compressVideo(
  //         file.path,
  //         quality: VideoQuality.HighestQuality, // Adjust the quality as needed
  //         deleteOrigin: false, // Optionally delete the original after compression
  //       );
  //
  //       if (compressedVideo != null) {
  //         file = XFile(compressedVideo.path!);
  //         setState(() {
  //           _message = "Uploading...";
  //         });
  //       } else {
  //         setState(() {
  //           _message = "Video compression failed.";
  //         });
  //         return;
  //       }
  //     }
  //   }
  //   else{
  //       setState(() {
  //         _message = "Uploading...";
  //       });
  //   }
  //
  //     var request = http.MultipartRequest('POST', Uri.parse('$_selectedServerUrl/upload'));
  //     request.files.add(await http.MultipartFile.fromPath('file', file.path));
  //
  //     Stopwatch stopwatch = Stopwatch()..start(); // Initialize and start the stopwatch
  //
  //     try {
  //       var streamedResponse = await request.send();
  //
  //       if (streamedResponse.statusCode == 200) {
  //         setState(() {
  //           _message = "Processing...";
  //         });
  //
  //         streamedResponse.stream.transform(utf8.decoder).join().then((responseBody) {
  //           var response = jsonDecode(responseBody);
  //           stopwatch.stop(); // Stop the stopwatch when the response is fully received
  //
  //           print('Upload successful: $response');
  //           setState(() {
  //             _imageUrl = '$_selectedServerUrl/get-media/${response['filename']}';
  //             _message = response['counts'];
  //             _timeelpsd = "You got this result in ${stopwatch.elapsed.inSeconds} seconds"; // Display elapsed time
  //             if (response['filename'].endsWith('.mp4') || response['filename'].endsWith('.avi')) {
  //               _initializeVideo(_imageUrl!);
  //             } else {
  //               _videoController?.pause();
  //               _videoController = null;
  //             }
  //           });
  //         });
  //       } else {
  //         print('Upload failed with status: ${streamedResponse.statusCode}');
  //         setState(() {
  //           _message = "Upload failed";
  //         });
  //       }
  //     } catch (e) {
  //       print('Exception during upload: $e');
  //       setState(() {
  //         _message = "Failed to connect. Please try again.";
  //       });
  //     }
  //   }


  Future<void> _uploadFile(XFile? file) async {
    if (file == null) return;

    print('C O M P R E S S : $_compressVideo');
    if (_compressVideo) {
      // Start uploading message
      setState(() {
        _message = "Preparing upload...";
      });

      final String filepath = file.path;
      // Check if the file is a video and compress it using FFmpeg
      if (file.path.endsWith('.mp4') || file.path.endsWith('.avi')) {
        setState(() {
          _message = "Compressing video...";
        });

        // Construct the new filename for the compressed video
        final String dirname = path.dirname(file.path);
        final String basename = path.basenameWithoutExtension(file.path);
        final String extension = path.extension(file.path);
        final String compressedFilename = "${basename}_compressed${extension}";
        final String outputPath = path.join(dirname, compressedFilename);

        // Construct FFmpeg command for compression
        final String ffmpegCommand = '-i "${file.path}" -c:v mpeg1video -b:v 500k  -r 30 "$outputPath"';

        // Execute FFmpeg command
        await _ffmpeg.execute(ffmpegCommand).then((returnCode) async {
          if (returnCode == 0) {
            file = XFile(outputPath); // Update the file variable to the compressed file's path
            setState(() {
              _message = "Uploading...";
            });
          } else {
            setState(() {
              _message = "Video compression failed.";
            });
            return; // Exit if compression fails
          }
        });
      }

      else if (filepath.endsWith('.jpg') || filepath.endsWith('.jpeg') || filepath.endsWith('.png')) {
        // Compress images
        setState(() {
          _message = "Compressing image...";
        });

        final Uint8List? compressedImage = await FlutterImageCompress.compressWithFile(
          filepath,
          minWidth: 1920,
          minHeight: 1080,
          quality: 50, // Adjust quality as needed
        );

        if (compressedImage != null) {
          final String dir = path.dirname(filepath);
          final String basename = path.basenameWithoutExtension(filepath);
          final String extension = path.extension(filepath);
          final String newFilePath = path.join(dir, "${basename}_compressed$extension");

          setState(() {
            _message = "Uploading...";
          });


          await File(newFilePath).writeAsBytes(compressedImage);
          file = XFile(newFilePath); // Update the file variable to the compressed file's path
        } else {
          setState(() {
            _message = "Image compression failed.";
          });
          return; // Exit if compression fails
        }
      }
    } else {
      setState(() {
        _message = "Uploading...";
      });
    }

    // Prepare and send the HTTP multipart request
    var request = http.MultipartRequest('POST', Uri.parse('$_selectedServerUrl/upload'));
    request.files.add(await http.MultipartFile.fromPath('file', file!.path));

    Stopwatch stopwatch = Stopwatch()..start(); // Initialize and start the stopwatch

    try {
      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        setState(() {
          _message = "Processing...";
        });

        streamedResponse.stream.transform(utf8.decoder).join().then((responseBody) {
          var response = jsonDecode(responseBody);
          stopwatch.stop(); // Stop the stopwatch when the response is fully received

          print('Upload successful: $response');
          setState(() {
            _imageUrl = '$_selectedServerUrl/get-media/${response['filename']}';
            _message = response['counts'];
            _timeelpsd = "You got this result in ${stopwatch.elapsed.inSeconds} seconds"; // Display elapsed time
            if (response['filename'].endsWith('.mp4') || response['filename'].endsWith('.avi')) {
              _initializeVideo(_imageUrl!);
            } else {
              _videoController?.pause();
              _videoController = null;
            }
          });
        });
      } else {
        print('Upload failed with status: ${streamedResponse.statusCode}');
        setState(() {
          _message = "Upload failed";
        });
      }
    } catch (e) {
      print('Exception during upload: $e');
      setState(() {
        _message = "Failed to connect. Please try again.";
      });
    }
  }



  // Future<void> _uploadFile(XFile? file) async {
  //   if (file == null) return;
  //
  //   setState(() {
  //     _message = "Uploading...";
  //   });
  //
  //   var request = http.MultipartRequest('POST', Uri.parse('$_selectedServerUrl/upload'));
  //   request.files.add(await http.MultipartFile.fromPath('file', file.path));
  //
  //   Stopwatch stopwatch = Stopwatch()..start(); // Initialize and start the stopwatch
  //
  //   try {
  //     var streamedResponse = await request.send();
  //
  //     if (streamedResponse.statusCode == 200) {
  //       setState(() {
  //         _message = "Processing...";
  //       });
  //
  //       streamedResponse.stream.transform(utf8.decoder).join().then((responseBody) {
  //         var response = jsonDecode(responseBody);
  //         stopwatch.stop(); // Stop the stopwatch when the response is fully received
  //
  //         print('Upload successful: $response');
  //         setState(() {
  //           _imageUrl = '$_selectedServerUrl/get-media/${response['filename']}';
  //           _message = response['counts'];
  //           _timeelpsd = "You got this result in ${stopwatch.elapsed.inSeconds} seconds"; // Display elapsed time
  //           if (response['filename'].endsWith('.mp4') || response['filename'].endsWith('.avi')) {
  //             _initializeVideo(_imageUrl!);
  //           } else {
  //             _videoController?.pause();
  //             _videoController = null;
  //           }
  //         });
  //       });
  //     } else {
  //       print('Upload failed with status: ${streamedResponse.statusCode}');
  //       setState(() {
  //         _message = "Upload failed";
  //       });
  //     }
  //   } catch (e) {
  //     print('Exception during upload: $e');
  //     setState(() {
  //       _message = "Failed to connect. Please try again.";
  //     });
  //   }
  // }

  void _initializeVideo(String url) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.network(url)
      ..initialize().then((_) {
        setState(() {
          _videoController!.play();
        });
      });
  }

  Future<bool> _requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    else if (!status.isPermanentlyDenied) {
      openAppSettings();
    }

    return status.isGranted;
  }




  Future<void> _saveMedia() async {
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Media URL is invalid.'))
      );
      return;
    }

    // if (!(await _requestStoragePermission())) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text('Storage permission not granted.'))
    //   );
    //   return;
    // }

    _requestStoragePermission();

    try {
      if (_imageUrl!.endsWith('.mp4') || _imageUrl!.endsWith('.avi')) {
        // New method for handling video download
        var dir = await DownloadsPathProvider.downloadsDirectory;
        if (dir != null) {
          String saveFileName = _imageUrl!.split('/').last; // Use the file name from the URL or set your own
          String savePath = "${dir.path}/$saveFileName";
          await Dio().download(
              _imageUrl!,
              savePath,
              onReceiveProgress: (received, total) {
                if (total != -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Download progress: ${(received / total * 100).toStringAsFixed(0)}%'))
                  );
                }
              }
          );
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Video saved successfully!'))
          );
        }
      } else {
        // Handling image download as before
        final response = await http.get(Uri.parse(_imageUrl!));
        if (response.statusCode != 200) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to download media from server.'))
          );
          return;
        }
        if (response.contentLength == 0 || response.bodyBytes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Downloaded media is empty.'))
          );
          return;
        }

        final Uint8List bytes = response.bodyBytes;
        final result = await ImageGallerySaver.saveImage(bytes, quality: 60, name: "downloaded_media");
        if (result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Media saved successfully!'))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save media.'))
          );
        }
      }
    } catch (e) {
      print('Error saving media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save media: $e'))
      );
    }
  }





  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }


  Widget _buildVideoControls() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return SizedBox.shrink(); // Returns an empty container if there is no video controller or it's not initialized.
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          // Check if the video is playing and either play or pause accordingly.
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
          } else {
            _videoController!.play();
          }
        });
      },
      child: Container(
        alignment: Alignment.bottomCenter,
        // color: Colors.black45, // Semi-transparent overlay for better visibility of icons
        child: Icon(
          _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload and Display Media'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              DropdownButton<ServerOption>(
                value: serverOptions.firstWhere((option) => option.url == _selectedServerUrl),
                onChanged: (ServerOption? newValue) {
                  setState(() {
                    _selectedServerUrl = newValue!.url;
                  });
                },
                items: serverOptions.map((ServerOption option) {
                  return DropdownMenuItem<ServerOption>(
                    value: option,
                    child: Text(option.name),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center everything horizontally
                crossAxisAlignment: CrossAxisAlignment.center, // Center everything vertically
                children: [
                  Switch(
                    value: _compressVideo,
                    onChanged: (bool value) {
                      setState(() {
                        _compressVideo = value;
                        print(_compressVideo);
                      });
                    },
                  ),
                  SizedBox(width: 20), // Provide some space between the switch and the button
                  ElevatedButton(
                    onPressed: _pickMedia,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                    child: Text('Pick Media'),
                  ),
                ],
              ),


              SizedBox(height: 20),
              if (_message != null) Text(_message!),
              // SizedBox(height: 20),
              // if (_counts != null) Text(_counts!),
              SizedBox(height: 20),
              if (_imageUrl != null && _videoController == null)
                Expanded(
                  child: PhotoView(
                    imageProvider: NetworkImage(_imageUrl!),
                    backgroundDecoration: BoxDecoration(color: Colors.white),
                    minScale: PhotoViewComputedScale.contained * 1,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  ),
                ),
              if (_videoController != null && _videoController!.value.isInitialized)
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                      _buildVideoControls(),
                    ],
                  ),
                ),
              if (_imageUrl != null)
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveMedia,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  child: Text('Download Media'),
                ),
              SizedBox(height: 20),
              if (_timeelpsd != null) Text(
                _timeelpsd!,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.normal, fontStyle: FontStyle.italic, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ServerOption {
  final String url;
  final String name;

  ServerOption({required this.url, required this.name});
}