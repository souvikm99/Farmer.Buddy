import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'p2pVideo.dart';

void main() {
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  } else if (WebRTC.platformIsAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(liveVidServerPage());
}

class liveVidServerPage extends StatelessWidget {
  const liveVidServerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: P2PVideo(),
      // Scaffold(
      //   body: Center(
      //     child: Text(
      //       "Hello",
      //     ),
      //   ),
      // ),
    );
  }
}



// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:http/http.dart' as http;
//
// void main() {
//   runApp(MaterialApp(home: liveVidServerPage()));
// }
//
// class liveVidServerPage extends StatefulWidget {
//   @override
//   _LiveVidClientPageState createState() => _LiveVidClientPageState();
// }
//
// class _LiveVidClientPageState extends State<liveVidServerPage> {
//   late RTCPeerConnection _peerConnection;
//   late MediaStream _localStream;
//   RTCVideoRenderer _localRenderer = RTCVideoRenderer();
//   RTCDataChannel? _dataChannel;
//   final String serverUrl = 'http://10.128.6.187:5050';
//
//   @override
//   void initState() {
//     super.initState();
//     _initWebRTC();
//   }
//
//   Future<void> _initWebRTC() async {
//     await _localRenderer.initialize();
//     _localStream = await navigator.mediaDevices.getUserMedia({
//       'audio': true,
//       'video': {'facingMode': 'user'}
//     });
//
//     _peerConnection = await createPeerConnection({
//       'iceServers': [
//         {'url': 'stun:stun.l.google.com:19302'},
//       ]
//     }, {});
//
//     _localStream.getTracks().forEach((track) {
//       _peerConnection.addTrack(track, _localStream);
//     });
//
//     _peerConnection.onDataChannel = (RTCDataChannel channel) {
//       _dataChannel = channel;
//       channel.onMessage = (RTCDataChannelMessage message) {
//         print('Received data from server: ${message.text}');
//       };
//     };
//
//     _fetchOfferAndCreateAnswer();
//   }
//
//   Future<void> _fetchOfferAndCreateAnswer() async {
//     final response = await http.get(Uri.parse('$serverUrl/offer'));
//     if (response.statusCode == 200) {
//       final offer = json.decode(response.body);
//       await _peerConnection.setRemoteDescription(
//           RTCSessionDescription(offer['sdp'], offer['type'])
//       );
//
//       final answer = await _peerConnection.createAnswer();
//       await _peerConnection.setLocalDescription(answer);
//       _sendAnswerToServer(answer);
//     } else {
//       throw Exception('Failed to fetch offer from server');
//     }
//   }
//
//   Future<void> _sendAnswerToServer(RTCSessionDescription answer) async {
//     final response = await http.post(
//       Uri.parse('$serverUrl/answer'),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode({
//         'sdp': answer.sdp,
//         'type': answer.type,
//       }),
//     );
//     if (response.statusCode != 200) {
//       print('Failed to send answer to server');
//     }
//   }
//
//   @override
//   void dispose() {
//     _peerConnection.close();
//     _localRenderer.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Flutter WebRTC Example'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Text('WebRTC Communication'),
//             Container(
//               width: 200,
//               height: 200,
//               child: RTCVideoView(_localRenderer),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


