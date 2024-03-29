import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:object_detection/server_page.dart';
import 'package:object_detection/test.dart';
import 'package:object_detection/video_page.dart';
import 'package:camera/camera.dart';
import 'ImageHomeScreen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

List<CameraDescription>? cameras;
void main() async{
  runApp(MyApp());
  cameras = await availableCameras();
}

class MyApp extends StatelessWidget {
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
      'COUNT FROM IMAGE',
      'LIVE COUNTING',
      'COUNT WITH CLOUD',
      'TRAINING',
      'AGRICULTURAL SUPPORT',
      'CUSTOMER SUPPORT'
    ];
    List<Widget> icons = [
      Image.asset('assets/count_with_image.png', width: 80.0, height: 80.0),
      Image.asset('assets/live_vid_count_icon.png', width: 100.0, height: 100.0),
      Image.asset('assets/cloud.png', width: 100.0, height: 100.0),
      Image.asset('assets/training.png', width: 100.0, height: 100.0),
      Image.asset('assets/support_agr.png', width: 80.0, height: 80.0),
      Image.asset('assets/support.png', width: 100.0, height: 100.0)
    ];

    List<Widget> destinations = [
      ImageHomeApp(),
      VideoPage(),
      ServerPage(),
      TestApp(),
      // Add your other destination widgets here
    ];

    return Scaffold(
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
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0), // Reduced top padding
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
                        5.5 / 6.5,
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

          // Weather Data Widget
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),             // color: Colors.white, // Background color of the weather data widget
            child: Column(
              children: [
                // Assuming you want to display a single row of live weather data
                FutureBuilder<Position>(
                  future: getCurrentLocation(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                      return LiveWeatherWidget();
                    } else if (snapshot.hasError) {
                      return Text("Error fetching location");
                    }
                    return CircularProgressIndicator();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// class FarmingDashboard extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     List<String> titles = [
//       'COUNT FROM IMAGE',
//       'LIVE COUNTING',
//       'COUNT WITH CLOUD',
//       'TRAINING',
//       'AGRICULTURAL SUPPORT',
//       'CUSTOMER SUPPORT',
//     ];
//
//     List<Widget> icons = [
//       Image.asset('assets/count_with_image.png', width: 80.0, height: 80.0),
//       Image.asset('assets/live_vid_count_icon.png', width: 100.0, height: 100.0),
//       Image.asset('assets/cloud.png', width: 100.0, height: 100.0),
//       Image.asset('assets/training.png', width: 100.0, height: 100.0),
//       Image.asset('assets/support_agr.png', width: 80.0, height: 80.0),
//       Image.asset('assets/support.png', width: 100.0, height: 100.0),
//     ];
//
//     List<Widget> destinations = [
//       ImageHomeApp(),
//       VideoPage(),
//       ServerPage(),
//       TestApp(),
//       // Add your other destination widgets here
//     ];
//
//     return Container(
//       decoration: BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage("assets/FarmerbuddyBg.png"), // Specify your image path
//           fit: BoxFit.cover, // This will cover the entire background
//         ),
//       ),
//       child: Scaffold(
//         backgroundColor: Colors.transparent, // Make scaffold background transparent
//         body: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             SafeArea(
//               child: Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//                 child: Material(
//                   elevation: 0.1,
//                   color: Color(0xFFF9FAF2).withOpacity(0.5), // Optional: make top bar slightly transparent
//                   borderRadius: BorderRadius.circular(5.0),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: <Widget>[
//                         Icon(Icons.menu, color: Colors.green),
//                         Text(
//                           'Farmer Buddy',
//                           style: TextStyle(
//                             color: Colors.green,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 24.0,
//                           ),
//                         ),
//                         Icon(Icons.notifications, color: Colors.green),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Container(
//                   padding: EdgeInsets.fromLTRB(20, 0, 20, 0), // Reduced top padding
//                   child: GridView.custom(
//                     shrinkWrap: true,
//                     physics: NeverScrollableScrollPhysics(),
//                     gridDelegate: SliverWovenGridDelegate.count(
//                       crossAxisCount: 2,
//                       mainAxisSpacing: 0.3,
//                       crossAxisSpacing: 0.3,
//                       pattern: [
//                         WovenGridTile(1),
//                         WovenGridTile(
//                           5.5 / 6.5,
//                           crossAxisRatio: 0.95,
//                           alignment: AlignmentDirectional.centerEnd,
//                         ),
//                       ],
//                     ),
//                     childrenDelegate: SliverChildBuilderDelegate(
//                           (context, index) {
//                         int row = index ~/ 2; // Integer division to find row
//                         int col = index % 2; // Modulo to find column
//                         Color bgColor = (row + col) % 2 == 0 ? Color(0x1A66ff33) : Color(0x33c7e600);
//
//                         return Material(
//                           elevation: 0.8, // The elevation provides the shadow
//                           borderRadius: BorderRadius.circular(30), // Consistent with your Container's border radius
//                           shadowColor: Colors.green.shade900.withOpacity(0.2), // Custom shadow color
//                           child: InkWell(
//                             onTap: () {
//                               Navigator.push(
//                                 context,
//                                 MaterialPageRoute(builder: (context) => destinations[index % destinations.length]),
//                               );
//                             },
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 color: bgColor, // Use calculated background color
//                                 borderRadius: BorderRadius.circular(30),
//                               ),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: <Widget>[
//                                   icons[index], // Directly use the widget without wrapping it in an Icon widget
//                                   Padding(
//                                     padding: const EdgeInsets.only(top: 8.0), // Add some spacing between the icon and text
//                                     child: Text(
//                                       titles[index],
//                                       textAlign: TextAlign.center,
//                                       style: TextStyle(
//                                         color: Colors.green[800], // Example style
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                       childCount: titles.length, // Number of tiles
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             // Weather Data Widget
//             Container(
//               padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
//               child: Column(
//                 children: [
//                   // Assuming you want to display a single row of live weather data
//                   FutureBuilder<Position>(
//                     future: getCurrentLocation(),
//                     builder: (context, snapshot) {
//                       if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
//                         return LiveWeatherWidget();
//                       } else if (snapshot.hasError) {
//                         return Text("Error fetching location");
//                       }
//                       return CircularProgressIndicator();
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


class WeatherInfo extends StatelessWidget {
  final String title;
  final String subtitle;

  const WeatherInfo({Key? key, required this.title, required this.subtitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(subtitle),
      ],
    );
  }
}

class LiveWeatherWidget extends StatelessWidget {
  const LiveWeatherWidget({Key? key}) : super(key: key);

  Future<String> getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        var place = placemarks.first;
        return "${place.locality}, ${place.country}";
      } else {
        return "Unknown location";
      }
    } catch (e) {
      print(e);
      return "Location error";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: getCurrentLocation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          final latitude = snapshot.data!.latitude;
          final longitude = snapshot.data!.longitude;
          final weatherFuture = fetchWeather(latitude, longitude);
          final locationNameFuture = getLocationName(latitude, longitude);

          return FutureBuilder<Map<String, dynamic>>(
            future: weatherFuture,
            builder: (context, weatherSnapshot) {
              return FutureBuilder<String>(
                future: locationNameFuture,
                builder: (context, locationSnapshot) {
                  if (weatherSnapshot.hasData && locationSnapshot.hasData) {
                    var weatherData = weatherSnapshot.data!;
                    var locationName = locationSnapshot.data!;
                    var temp = "${weatherData['main']['temp']}°C";
                    var description = weatherData['weather'][0]['description'];
                    var iconCode = weatherData['weather'][0]['icon'];
                    var imageUrl = "http://openweathermap.org/img/w/$iconCode.png";
                    var windSpeed = "${weatherData['wind']['speed']} m/s";
                    var humidity = "${weatherData['main']['humidity']}%";
                    var rain = weatherData.containsKey('rain') ? "${weatherData['rain']['1h']} mm" : '0 mm';

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8.0), // Reduced top padding
                        child: Container(
                          padding: EdgeInsets.all(10), // Add padding here
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12), // Make the corners round
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFF9FAF2), // Add a drop shadow
                                spreadRadius: 5,
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(imageUrl, width: 40),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(temp, style: Theme.of(context).textTheme.bodyText1),
                                        Text(description, style: Theme.of(context).textTheme.caption),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Chip(
                                          avatar: Icon(Icons.location_on, size: 10, color: Colors.black45),
                                          label: Text(locationName, style: TextStyle(fontSize: 10,color: Colors.black45)),
                                          // backgroundColor: Colors.teal,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 20, thickness: 1),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    label: Text(
                                      windSpeed,
                                      style: TextStyle(fontSize: 8, color: Colors.black),
                                    ),
                                    avatar: Image.asset('assets/icons8-wind.gif', width: 15, height: 15),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    // backgroundColor: Colors.lightBlue.shade100,
                                  ),
                                  Chip(
                                    label: Text(
                                      humidity,
                                      style: TextStyle(fontSize: 8, color: Colors.black),
                                    ),
                                    avatar: Image.asset('assets/icons8-hygrometer.gif', width: 15, height: 15),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    // backgroundColor: Colors.lightBlue.shade100,
                                  ),
                                  Chip(
                                    label: Text(
                                      rain,
                                      style: TextStyle(fontSize: 8, color: Colors.black),
                                    ),
                                    avatar: Image.asset('assets/icons8-rain.gif', width: 15, height: 15), // Use GIF asset for the avatar
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    // backgroundColor: Colors.lightBlue.shade100,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    return CircularProgressIndicator();
                  }
                },
              );
            },
          );
        } else {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}












