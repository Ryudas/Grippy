import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart'; // google maps API
import 'package:geolocator/geolocator.dart'; // package for geolocation
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // bluetooth serial library


import 'markers.dart';
import 'logging.dart';
import 'glove.dart';

// logging only works for Android
// run my app, while creating a DataStorage object for logging
void main(){
  runApp( MaterialApp(
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == '/') {
          return new MaterialPageRoute<Null>(
            settings: settings,
            builder: (_) => MyApp(storage: DataStorage()),
            maintainState: false,
          );
        }
        return null;
      }
  ));
}

class MyApp extends StatefulWidget {
  MyApp({Key key, @required this.storage}) : super(key: key);

  final DataStorage storage;
  @override
  _MyAppState createState() => _MyAppState();
}

// widgets binding observer checks status of app
class _MyAppState extends State<MyApp> with WidgetsBindingObserver{

  // Map location markers
   Map<String, Marker> _markers = <String, Marker>{};

  // current user location marker
  Marker _curr_location;


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


  // creating google map controller object
  GoogleMapController _map_controller;
  // bluetooth state
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;


  // class , type of object that represents a position in the world
  final LatLng _center = const LatLng(52.011578, 4.357068); // Latitude longitude

  // bluetooth address and name
  String _bl_adapter_address;
  String _bl_adapter_name;

  // List of devices with availability
  List<BluetoothDevice> available_devices = <BluetoothDevice>[];
  // Rssi of desired device
  int _desired_device_rssi;

  // bluetooth serial connection
  BluetoothConnection _bl_serial_connection;
  // whether device is connected to serial
  bool _is_connected_to_serial = false;
  // if bluetooth discovering is active (starts active)
  bool _is_discovering = true;

  // messages buffer from an connection, with incomplete helper buffer
  List<String> messages = <String>[];
  String _temp_message_buffer = "";

  // icon for location
  BitmapDescriptor loc_icon;

  // activity running average object (frequency denotes how often inactivity
  // should be given out, sample rate establishes glove output data rate
  ActivityRunningAvg running_avg = ActivityRunningAvg(15,5);

  // when map object is created
  void _onMapCreated(GoogleMapController controller) {
    _map_controller = controller;
  }


  // monitor app lifecycle state
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch(state) {
      case AppLifecycleState.resumed:
      // Handle this case
        break;
      case AppLifecycleState.inactive:
      // Handle this case
        break;
      case AppLifecycleState.paused:
      // Handle this case
        break;
      case AppLifecycleState.suspending:
      // Handle this case
        break;
    }
  }

  // registering our sensor stream subscriptions
  // called when stateful widget is inserted in widget tree.
  @override
  void initState() {
    super.initState(); // must be included
    // must be included
    WidgetsBinding.instance.addObserver(this);

    widget.storage.write_data("${DateTime.now()}");


    BitmapDescriptor.fromAssetImage( ImageConfiguration(bundle: rootBundle),
                                     "assets/medal/4.0x/icon.png"
    ).then( (BitmapDescriptor icon) {
        setState(() {
          loc_icon = icon;
        });
    });

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() { _bluetoothState = state; });
    });
    // asynchronous calls while bluetooth is not enabled  every 200ms
    Future.doWhile( () async {
      if( await FlutterBluetoothSerial.instance.isEnabled) {
        return(false);
      }
      await Future.delayed(Duration(milliseconds: 200));
      return(true);
    }).then( (_) {  // _ is a parameter argument  that we ignore
          // Update the address field
          FlutterBluetoothSerial.instance.address.then( (address) {
            setState(() { _bl_adapter_address = address; });
          });
       });

    // listen when bluetooth instance has a name
    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() { _bl_adapter_name = name; });
    });


    // Listen for further state changes to bluetooth adapter
    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    if(_is_discovering){
      _start_discovering_devices();
    }

/*
 // Setup a list of the paired devices
    FlutterBluetoothSerial.instance.getBondedDevices().then((List<BluetoothDevice> paired_devices) {
        available_devices += paired_devices;
        _connect_to_device(available_devices[0].address);
    });
*/
    _process_paired_devices();

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
        geolocator.getPositionStream(location_options).listen((Position event) {
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

  // disposal measures at the end of widget
  @override
  void dispose(){
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

    if(_bl_serial_connection.isConnected && _bl_serial_connection != null) {
      //  Avoid memory leak (`setState` after dispose) and disconnect
      _bl_serial_connection?.dispose();
      _bl_serial_connection = null;

      debugPrint("Disconnecting locally.");
    }

    // unsubscribe from open streams to prevent memory leaks
    for (StreamSubscription<dynamic> subscription in _stream_subscriptions) {
      subscription?.cancel();
    }
   }

  @override
  void deactivate(){
    super.deactivate();
    // deactivate connection

    if(_bl_serial_connection.isConnected && _bl_serial_connection != null) {
      //  Avoid memory leak (`setState` after dispose) and disconnect
      _bl_serial_connection?.dispose();
      _bl_serial_connection = null;

      debugPrint("Disconnecting locally.");
    }

    setState(() {
      // not connected anymore
      _is_connected_to_serial = false;
      // try to find device
      _is_discovering = true;
    });
  }

  @override
  Widget build(BuildContext context) {

    if(_is_discovering){
      _start_discovering_devices();
    }

    if(_loc_values != null)
    {
        _curr_location = Marker( markerId: MarkerId("location"),
                                position: LatLng(double.parse(_loc_values[0]),
                                                 double.parse(_loc_values[1])
                                          ),
        // if icon is available, else use blue marker
        icon:  loc_icon ??  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }

    // if current location is null, don't do anything
    if(_curr_location != null)  _markers.addAll({"loc" : _curr_location});

    /* Prints for debug
    debugPrint("Num Markers: ${_markers.length}");
    debugPrint("Current location: ${_curr_location.toString()}");

    debugPrint("Local bluetooth state enabled: ${_bluetoothState.isEnabled}");
    debugPrint("Local bluetooth adapter name: ${_bl_adapter_name}");
    debugPrint("Local bluetooth adapter name: ${_bl_adapter_address}");

    debugPrint("Available paired devices: ${available_devices[0].toString()}");
    */


    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Strain Manager'),
          backgroundColor: Color(0xFF0085AC),
          // in case we have recording, adding a record button
          leading: Visibility(
            // doing this so I can get largest size possible for icon
            child:  LayoutBuilder(builder: (context, constraint) {
              return Icon(Icons.adjust,size: constraint.biggest.height *.75, color: Colors.redAccent);
            }),
            visible: _is_connected_to_serial,
            replacement: LayoutBuilder(builder: (context, constraint) {
              return Icon(Icons.adjust,size: constraint.biggest.height *.75, color: Colors.grey);
            }),
          ),
        ),
        body: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _curr_location?.position ?? _center,
                zoom: 15.0,

              ),
              markers:_markers.values.toSet(),
            ),
        )
    );
  }

  void _stop_monitoring_devices()
  {
  _stream_subscriptions[0].pause();
}

  void _start_monitoring_devices()
  {
   _stream_subscriptions[0].resume();
 }

  void _on_data_received(Uint8List data)
  {
   // Allocate buffer for parsed data
   int backspacesCounter = 0;
   data.forEach((byte) {
     if (byte == 8 || byte == 127) {
       backspacesCounter++;
     }
   });

   Uint8List buffer = Uint8List(data.length - backspacesCounter);
   int bufferIndex = buffer.length;

   // Apply backspace control character
   backspacesCounter = 0;
   for (int i = data.length - 1; i >= 0; i--) {
     if (data[i] == 8 || data[i] == 127) {
       backspacesCounter++;
     }
     else {
       if (backspacesCounter > 0) {
         backspacesCounter--;
       }
       else {
         buffer[--bufferIndex] = data[i];
       }
     }
   }

   // Create message if there is new line character
   String dataString = String.fromCharCodes(buffer);
   // index of endline ASCII character
   int index = buffer.indexOf(13);

   if (~index != 0) { // \r\n
       messages.add(
           //  are there backspaces, then buffer is a substring
           (backspacesCounter > 0 )?
               _temp_message_buffer.substring(0, _temp_message_buffer.length - backspacesCounter)
               : _temp_message_buffer + dataString.substring(0, index)
       );
       _temp_message_buffer = dataString.substring(index).trim();

       // handle most current message data
       handle_glove_data(messages.last);

   }
   else {
     _temp_message_buffer = (
         backspacesCounter > 0
             ? _temp_message_buffer.substring(0, _temp_message_buffer.length - backspacesCounter)
             : _temp_message_buffer
             + dataString
     );
   }

/*
   // store messages
   widget.storage.write_data(messages[0]).then( (File my_file){
     debugPrint("${my_file.length()}");
   });
*/

   debugPrint("${messages.last}");
 }

  // sends message through bluetooth connection
  void _sendMessage(String text)
  {
   // remove leading and trailing spaces
   text = text.trim();

   if (text.isNotEmpty)  {
     _bl_serial_connection.output.add(utf8.encode(text + "\r\n"));
   }

 }

  // connect to bluetooth device given its address
  void _connect_to_device(String address)
  {
   // bluetooth connection to glove address
   BluetoothConnection.toAddress(address).then((_connection) {
     debugPrint('Connected to the device');
     _bl_serial_connection = _connection;

     setState(() {
       _is_connected_to_serial = true;
     });


     _bl_serial_connection.input.listen(_on_data_received).onDone(() {
       debugPrint('Disconnected by remote request');
       _bl_serial_connection.finish();
       setState(() {
         // not connected anymore
         _is_connected_to_serial = false;
         // try to find device
         _is_discovering = true;
       });


     });
   });
 }

  // Starts discovering available bluetooth devices
  void _start_discovering_devices()
  {
   // Adding a subscription stream for searching/updating bluetooth devices
   _stream_subscriptions.add(
       FlutterBluetoothSerial.instance.startDiscovery().listen( (response) {
         setState(() {
           Iterator i = available_devices.iterator;
           // iterate through devices
           while (i.moveNext()) {
             // get current device
             BluetoothDevice device = i.current;
             // update its rssi value
             if (device == response.device) {
               _desired_device_rssi = response.rssi;
             }
           }
         });
       })
   );

   // CAREFUL HERE, using last....
   _stream_subscriptions.last.onDone(() {
      _is_discovering = false;
   });

 }

  // Gets Paired devices, and connects to desired one
  void _process_paired_devices()
  {
   // Setup a list of the paired devices
   FlutterBluetoothSerial?.instance?.getBondedDevices()?.then((List<BluetoothDevice> paired_devices) {
     available_devices += paired_devices;
     _connect_to_device(available_devices[0].address);
   });

 }

  void handle_glove_data(String data)
  {

  // log incoming raw string glove data
  widget.storage.write_data(data);
  messages.removeLast();

  // parse glove data into prepared object
  var glove_data = GloveData(data);
  running_avg.add_data_pt(glove_data.steps);


  // process inactivity given a threshold of steps
  if(running_avg?.get_inactivity(50)){
    // do inactivity actions
  }

  // process stress ( 100 - 130 - heart attack)
  if( glove_data?.heart_rate < 100){
    // normal
  } else if (glove_data.heart_rate < 130){ // mid to high
    // mid
  } else{
    // high warning!
  }

  // process challenge
  if(glove_data?.challenge){
    // send data
  }

}

}


