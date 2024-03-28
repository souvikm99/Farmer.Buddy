import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:object_detection/server_page.dart';
import 'package:object_detection/single_image.dart';
import 'package:object_detection/test.dart';
import 'package:object_detection/video_page.dart';
import 'package:camera/camera.dart';
import 'ImageHomeScreen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'mult_image.dart';

class ImageHomeApp extends StatefulWidget {
  @override
  _ImageHomeAppState createState() => _ImageHomeAppState();
}

class _ImageHomeAppState extends State<ImageHomeApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmer Buddy',
      theme: ThemeData(
        // Apply GoogleFonts to the entire app
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: FarmingDashboard(),
    );
  }
}

Future<Position> getCurrentLocation() async {
  LocationPermission permission;
  permission = await Geolocator.requestPermission();
  return await Geolocator.getCurrentPosition();
}

Future<Map<String, dynamic>> fetchWeather(double latitude, double longitude) async {
  final apiKey = '6d9a0123ba909d6dbbe30714d05acc48'; // Replace with your OpenWeatherMap API key
  final requestUrl = 'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric';

  final response = await http.get(Uri.parse(requestUrl));

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load weather data');
  }
}

class FarmingDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<String> titles = [
      'Single Image',
      'Many Images',
    ];
    List<Widget> icons = [
      Image.asset('assets/single_images.png', width: 80.0, height: 80.0),
      Image.asset('assets/mult_images.png', width: 100.0, height: 100.0),
    ];

    List<Widget> destinations = [
      SingleImageCap(),
      MultImage(),
    ];

    return Scaffold(
      backgroundColor: Color(0xFFF4FCF7), //bg color of the whole page
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              // padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Material(
                elevation: 0.1,
                color: Color(0xFFF9FAF2),
                borderRadius: BorderRadius.circular(5.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Icon(Icons.menu, color: Colors.green), // Menu icon
                      Text(
                        'Farmer Buddy',
                        style: TextStyle(
                          color: Colors.green, // Adjust the color to match your brand color
                          fontWeight: FontWeight.bold,
                          fontSize: 24.0, // Adjust the font size to your preference
                        ),
                      ),
                      Icon(Icons.notifications, color: Colors.green), // Notifications icon
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(0, 100, 0, 0), // Reduced top padding
              child: Container(
                height: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top - 100 - 10,
                padding: EdgeInsets.fromLTRB(20, 80, 20, 0), // Reduced top padding
                decoration: BoxDecoration(
                  color: Colors.white, // Set your desired background color
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.0),
                    topRight: Radius.circular(40.0),
                  ),
                  // boxShadow: [ // Optional: if you want to add a shadow for better contrast
                  //   BoxShadow(
                  //     color: Colors.grey.withOpacity(0.5), // Shadow color
                  //     spreadRadius: 2, // Spread radius
                  //     blurRadius: 5, // Blur radius
                  //     offset: Offset(0, 3), // Shadow position
                  //   ),
                  // ],
                ),
                child: GridView.custom(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverWovenGridDelegate.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 0.3,
                    crossAxisSpacing: 0.3,
                    pattern: [
                      WovenGridTile(1),
                      WovenGridTile(
                        5 / 7,
                        crossAxisRatio: 0.95,
                        alignment: AlignmentDirectional.centerEnd,
                      ),
                    ],
                  ),
                  childrenDelegate: SliverChildBuilderDelegate(
                        (context, index) {
                      int row = index ~/ 2; // Integer division to find row
                      int col = index % 2; // Modulo to find column
                      Color bgColor = (row + col) % 2 == 0 ? Color(0x1A66ff33) : Color(0x33c7e600);

                      return Material(
                        elevation: 0.8, // The elevation provides the shadow
                        borderRadius: BorderRadius.circular(30), // Consistent with your Container's border radius
                        shadowColor: Colors.green.shade900.withOpacity(0.2), // Custom shadow color
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => destinations[index % destinations.length]),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgColor, // Use calculated background color
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                icons[index], // Directly use the widget without wrapping it in an Icon widget
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0), // Add some spacing between the icon and text
                                  child: Text(
                                    titles[index],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.green[800], // Example style
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: titles.length, // Number of tiles
                  ),
                ),

              ),
            ),
          ),
        ],
      ),
    );
  }
}










