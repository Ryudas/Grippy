import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // google maps API

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Map<String, Marker> _markers = { "one": Marker( markerId: MarkerId("one"),
                                                        position: LatLng(52.011034,4.357725),
                                                      )

                                       };

  GoogleMapController mapController;    // creating google map controler object

  final LatLng _center = const LatLng(52.011578, 4.357068); // Latitude longitude
  // class , type of object that represents a position in the world

  // when map object is created
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('strain manager'),
          backgroundColor: Colors.teal,
        ),
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _center,
            zoom: 11.0,

          ),
          markers:_markers.values.toSet(),
        ),
      ),
    );
  }
}