import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // google maps API
import 'package:geolocator/geolocator.dart'; // package for geolocation

import 'markers.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  // Map location markers
   Map<String, Marker> _markers = <String, Marker>{};

  // current user location marker
  Marker curr_location;


  // stores list of subscriptions to sensor event streams (async data sources)
  List<StreamSubscription<dynamic>> _stream_subscriptions =
  <StreamSubscription<dynamic>>[];

  // saves location data, 5D:
  // latitude in degrees normalized to the interval [-90.0,+90.0]
  // longitude in degrees normalized to the interval [-90.0,+90.0]
  // altitude in meters
  // speed at which the device is traveling in m/s over ground
  // timestamp time at which event was received from device
  List<String> _loc_values;

  GoogleMapController mapController;    // creating google map controler object

  final LatLng _center = const LatLng(52.011578, 4.357068); // Latitude longitude
  // class , type of object that represents a position in the world

  // when map object is created
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }


  // registering our sensor stream subscriptions
  // called when stateful widget is inserted in widget tree.
  @override
  void initState() {
    super.initState(); // must be included

    process_markers(context).then((Map <String, Marker> value) {
                              setState(() {
                                _markers.addAll(value);
                              });
                            });
    // Location subscription
    var geolocator = Geolocator();
    // desired accuracy and the minimum distance change
    // (in meters) before updates are sent to the application - 1m in our case.
    var location_options = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 1);
    _stream_subscriptions.add(
        geolocator.getPositionStream(location_options).listen(
                (Position event) {
              setState(() {
                _loc_values = <String>[event.latitude.toStringAsFixed(3),
                  event.longitude.toStringAsFixed(3),
                  event.altitude.toStringAsFixed(3),
                  event.speed.toStringAsFixed(3),
                  event.timestamp.toString()];

              });

            })
    );



  }

  @override
  Widget build(BuildContext context) {

    if(_loc_values != null)
    {
        curr_location = Marker( markerId: MarkerId("location"),
                                position: LatLng(double.parse(_loc_values[0]),
                                                 double.parse(_loc_values[1])
                                          ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }

    // if current location is null, don't do anything
    if(curr_location != null)  _markers.addAll({"loc" : curr_location});

    debugPrint("Num Markers: ${_markers.length}");
    debugPrint("Current location: ${curr_location.toString()}");

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Strain Manager'),
          backgroundColor: Color(0xFF0085AC),
        ),
        body: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: curr_location?.position ?? _center,
                zoom: 15.0,

              ),
              markers:_markers.values.toSet(),
            ),
        )
    );
  }
}