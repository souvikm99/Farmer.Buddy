import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() => runApp(MaterialApp(home: ServerPage()));

class ServerPage extends StatefulWidget {
  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;
  String? _message;

  Future<void> _uploadFile(XFile? file) async {
    if (file == null) return;

    setState(() {
      _message = "Uploading Image...";
    });

    var request = http.MultipartRequest('POST', Uri.parse('https://www.souvik.solutions/upload'));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    try {
      var streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        setState(() {
          _message = "Processing...";
        });

        streamedResponse.stream.transform(utf8.decoder).join().then((responseBody) {
          var response = jsonDecode(responseBody);
          print('Upload successful: $response');
          setState(() {
            _imageUrl = 'https://www.souvik.solutions/get-image/${response['filename']}';
            _message = null;  // Clear message once image is ready to be displayed
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

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _uploadFile(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload and Display Image'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  textStyle: TextStyle(fontSize: 16),
                ),
                child: Text('Pick and Upload Image'),
              ),
              SizedBox(height: 20),
              if (_message != null) Text(_message!),
              SizedBox(height: 20),
              if (_imageUrl != null)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1 / 1, // Assuming square for demonstration; change as needed.
                    child: Container(
                      padding: EdgeInsets.all(10), // Example of dynamic padding.
                      child: ClipRect(
                        child: Image.network(
                          _imageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                            return Text('Failed to load the image');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
