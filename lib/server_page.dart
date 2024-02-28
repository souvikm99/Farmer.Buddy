import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(ServerPage());
}

class ServerPage extends StatefulWidget {
  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  Uint8List? _imageBytes; // Updated to store image bytes

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = image;
      });
      _uploadImage(image);
    }
  }

  Future<void> _uploadImage(XFile image) async {
    var request = http.MultipartRequest('POST', Uri.parse('https://3a11-14-139-174-50.ngrok-free.app/detect'));
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    var streamedResponse = await request.send();
    if (streamedResponse.statusCode == 200) {
      final responseData = await streamedResponse.stream.toBytes();
      setState(() {
        _imageBytes = responseData;
      });
    } else {
      setState(() {
        _imageBytes = null;
      });
      print('Error: Could not process image');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('YOLOv5 Object Detection'),
        ),
        body: Column(
          children: <Widget>[
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Pick Image'),
            ),
            if (_image != null && _imageBytes != null)
              Image.memory(_imageBytes!)
            else if (_image != null)
              Image.file(File(_image!.path))
            else
              Container(),
          ],
        ),
      ),
    );
  }
}
