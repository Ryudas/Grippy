import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart'; // google maps API
import 'package:geolocator/geolocator.dart'; // package for geolocation
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // bluetooth serial library
import 'package:fluttertoast/fluttertoast.dart'; // package for displaying toast messages in app

import 'markers.dart';
import 'logging.dart';
import 'glove.dart';

// Logging only works for Android
// Run my app, while creating a DataStorage object for logging
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

// Widgets binding observer checks status of app
class _MyAppState extends State<MyApp> with WidgetsBindingObserver{


  // Map location markers
   Map<String, Marker> _markers = <String, Marker>{};

  // Map of possible marker icons
  Map<String, BitmapDescriptor> marker_icons= <String, BitmapDescriptor>{};

  // Current user location marker
  Marker _curr_location;


  // Stores list of subscriptions to sensor event streams (async data sources)
  List<StreamSubscription<dynamic>> _stream_subscriptions =
  <StreamSubscription<dynamic>>[];

  // saves location data, 5D:
  // latitude in degrees normalized to the interval [-90.0,+90.0]
  // longitude in degrees normalized to the interval [-90.0,+90.0]
  // altitude in meters
  // speed at which the device is traveling in m/s over ground
  // timestamp time at which event was received from device
  List<String> _loc_values;


  // Creating google map controller object
  GoogleMapController _map_controller;
  // Bluetooth state
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;


  // Class , type of object that represents a position in the world
  final LatLng _center = const LatLng(52.011578, 4.357068); // Latitude longitude

  // bluetooth address and name
  String _bl_adapter_address;
  String _bl_adapter_name;

   int _desired_device_rssi;

   // List of devices with availability
  List<BluetoothDevice> available_devices = <BluetoothDevice>[];

  // Bluetooth serial connection
  BluetoothConnection _bl_serial_connection;
  // Whether device is connected to serial
  bool _is_connected_to_serial = false;

  // If bluetooth discovering is active (starts active)
  bool _is_discovering = true;

  // Messages buffer from an connection, with incomplete helper buffer
  List<String> messages = <String>[];
  String _temp_message_buffer = "";

  // icon for location
  BitmapDescriptor loc_icon;

  // activity running average object (frequency denotes how often inactivity
  // should be given out (in seconds), sample rate establishes glove output data rate
  ActivityRunningAvg running_avg = ActivityRunningAvg(7200,5);
  // average steps threshold during defined time period for inactivity comparison
  // currently outputs to some 1000 steps over 2 hours -> total steps / 1440 ~ 0.7
  double step_threshold = .70;

  // distance threshold for warning near previous stress area (25 m)
  int _distance_threshold = 25;

  // previous received challenge, helps not sending continuous messaging
  bool previous_challenge = false;

  // previous pressure level (to ignore continuous messages on same level
  int prev_pressure_level= -1;


  // previous steps received, used to calculate step difference
  int prev_step_count = 0;
  // setting to stop stress alarm near position
  bool can_send_stress = true;


  // when map object is created
  void _onMapCreated(GoogleMapController controller) {
    _map_controller = controller;
  }


  // monitor app lifecycle state
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch(state) {
      case AppLifecycleState.resumed:
        setState(() {
          _bl_serial_connection = null;
          // Whether device is connected to serial
          _is_connected_to_serial = false;
        });
        _process_paired_devices();

      // Handle this case
        break;
      case AppLifecycleState.inactive:
        //dispose_bl_connection();
        break;
      case AppLifecycleState.paused:
      //  dispose_bl_connection();
        break;
      case AppLifecycleState.suspending:
       // dispose_bl_connection();
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

    // Location subscription
    var geolocator = Geolocator();
    // desired accuracy and the minimum distance change
    // (in meters) before updates are sent to the application - the detection range in our case.
    var location_options = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: _distance_threshold);
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


    widget.storage.write_data("${DateTime.now()}");


    BitmapDescriptor.fromAssetImage( ImageConfiguration(bundle: rootBundle),
                                     "assets/curr_loc/4.0x/icon.png"
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

    _process_paired_devices();

    // load saved markers in shared preferences
    process_markers(context).then((Map <String, Marker> value) {
                              setState(() {
                                _markers.addAll(value);
                              });
                            });

    load_icons().then((Map <String, BitmapDescriptor> value) {
                        marker_icons.addAll(value);
                 });

  }

  // disposal measures at the end of widget
  @override
  void dispose(){
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

    if(_bl_serial_connection != null && _bl_serial_connection.isConnected) {
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

  // handle deactivation procedures
  @override
  void deactivate(){
    super.deactivate();
    // deactivate connection

    if(_bl_serial_connection != null && _bl_serial_connection.isConnected ) {
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
    // are we discovering for bluetooth devices?

    if(_is_discovering){
      _start_discovering_devices();
    }

    // lets do our location processing code
    if(_loc_values != null)
    {
      // adding current location
        _curr_location = Marker( markerId: MarkerId("location"),
                                position: LatLng(double.parse(_loc_values[0]),
                                                 double.parse(_loc_values[1])
                                          ),
        // if icon is available, else use blue marker
        icon:  loc_icon ??  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );


      // checking for close distance to close spots
      if(_markers.isNotEmpty)
      {
        // iterate over every map entry


        _markers.forEach( ( String marker_id, Marker marker) {
          // everything but location
          if (marker_id != "loc")
          {
            var distance = Geolocator().distanceBetween(_curr_location.position.latitude,
                                                        _curr_location.position.longitude,
                                                        marker.position.latitude,
                                                        marker.position.longitude);

            distance.then( ( double dis_value) {
              // within threshold and not in the same place
              if(dis_value <= _distance_threshold && dis_value!= 0)
              {
                // trigger something
                // do high stress actions (index returns enum value)
                // begin challenge

                  send_message_persistent("${(GloveProtocol.challenge_detected.index)}");


            }

            });

          }
        });
      }
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
          title: Text('Grippy'),
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

  // Handle raw bluetooth data packet into string
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

       // process any empty messages
       if(messages.last == "")
       {
          messages.removeLast();
          return;
       }
       debugPrint("${messages.last}");
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

   //debugPrint("${messages.last}");
 }

  // Sends message through bluetooth connection
  void _sendMessage(String text) {
    // remove leading and trailing spaces
    text = text.trim();

    if (_bl_serial_connection != null && text.isNotEmpty) {
      _bl_serial_connection.output.add(utf8.encode(text + "\r\n"));
    }
  }



  // Connect to bluetooth device given its address
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
   }).catchError((error) {
     // call connect again
     _connect_to_device(address);
   });
 }

  // Starts discovering available bluetooth devices
  void _start_discovering_devices()
  {
   // Adding a subscription stream for searching/updating bluetooth devices
   _stream_subscriptions.add(
       FlutterBluetoothSerial.instance.startDiscovery().listen( (response) {

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


       })
   );

   // CAREFUL HERE, using last....
   _stream_subscriptions.last.onDone( () {
      _stream_subscriptions.removeLast();
      _is_discovering = false;
   });

 }

  // Gets Paired devices, and connects to desired one
  void _process_paired_devices()
  {
   // Setup a list of the paired devices
   FlutterBluetoothSerial?.instance?.getBondedDevices()?.then((List<BluetoothDevice> paired_devices) {
     available_devices += paired_devices;
     try {
       _connect_to_device(available_devices[0].address);
     } catch(e){
       // restart app connection
       _process_paired_devices();
     }
   });

 }

  // Handles glove data packet
  void handle_glove_data(String data)
  {

      // log incoming raw string glove data
      //widget.storage.write_data(data);
      //debugPrint("${messages.last}");

      // check message integrity 
      if( data.startsWith('s')  && data.endsWith('e')){
          // pop out string termination and start chars
          data = data.substring(1, data.length - 2 );
          messages.removeLast();

      }else{
        messages.removeLast();
        return;
      }


      // parse glove data into prepared object
      var glove_data = GloveData(data);

      if(!glove_data.comfort) {
        // get difference of steps from last sample
        if((glove_data.steps - prev_step_count) != 0) {
          running_avg.add_data_pt(glove_data.steps - prev_step_count);
        }

        // process inactivity given a threshold of steps
        if (running_avg.get_inactivity(step_threshold)) {
          // do inactivity actions

          send_message_persistent("${(GloveProtocol.inactivity_alarm.index)}");


          // debugPrint("${GloveProtocol.inactivity_alarm.index.toString()}");
          // log event
          //widget.storage.write_data("${DateTime.now().toUtc()}, Inactivity detected!\n");

          // show warning message
          Fluttertoast.showToast(
              msg: "You've been quite inactive so far!",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIos: 20,
              backgroundColor: Colors.cyan,
              textColor: Colors.white,
              fontSize: 16.0
          );
        }


        // process stress ( 100 - 130 - heart attack)
        if (glove_data?.heart_rate < 100) {
          // normal


        } else if (glove_data.heart_rate < 130) {
          // mid to high
        } else {
          // high warning!
          // do high stress actions (index returns enum value)
            if( can_send_stress) {
              send_message_persistent("${(GloveProtocol.stress_alarm.index)}");
            }




          // log event
          //widget.storage.write_data("${DateTime.now().toUtc()}, High stress detected!\n");

          // add marker( high stress) to map
          //place_marker("fist_red");

        }
      }

      // if pressure level is not 0
      if(glove_data.stress_level >= 0 && glove_data.stress_level != prev_pressure_level)
      {


          switch(glove_data.stress_level)
          {
            case 1:
            {
              Fluttertoast.showToast(
                  msg: "Self report of stress level 1",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  timeInSecForIos: 5,
                  backgroundColor: Colors.cyan,
                  textColor: Colors.white,
                  fontSize: 16.0
              );

              place_marker("fist_green");
            }
            break;

            case 2:
            {
              Fluttertoast.showToast(
                  msg: "Self report of stress level 2",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  timeInSecForIos: 5,
                  backgroundColor: Colors.cyan,
                  textColor: Colors.white,
                  fontSize: 16.0
              );

              place_marker("fist_yellow");
            }
            break;

            case 3:
            {
              Fluttertoast.showToast(
                  msg: "Self report of stress level 3",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  timeInSecForIos: 5,
                  backgroundColor: Colors.cyan,
                  textColor: Colors.white,
                  fontSize: 16.0
              );

              place_marker("fist_red");
            }
            break;
          }
      }


      // process challenge if challenge is running(comfort mode),
      // and the previous received was not a challenge
      if(glove_data.comfort && !previous_challenge){
        // send data

        Fluttertoast.showToast(
            msg: "Challenge started!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIos: 30,
            backgroundColor: Colors.cyan,
            textColor: Colors.white,
            fontSize: 16.0
        );
        //widget.storage.write_data("${DateTime.now().toUtc()}, Challenge started!\n");
        // do challenge actions (index returns enum value)
        //_sendMessage("${(GloveProtocol.challenge_vib.index)}");
        place_marker("medal");
      }

      // general log
      var date = DateTime.fromMillisecondsSinceEpoch(glove_data.timestamp * 1000);

      log_data(date, glove_data);


      // set previous message packet challenge status
      previous_challenge = glove_data.comfort;
      prev_pressure_level = glove_data.stress_level;
      prev_step_count = glove_data.steps;

  }

  // adds a particular marker to map, depending on stress value (low, medium high)
  // then add it to the shared preferences.
  void place_marker(String icon_id) {
    // useless if it is
    if (marker_icons.isEmpty) return;
    bool leave = false;
    // iterate over every map entry
    _markers.forEach((String marker_id, Marker marker) {
      // everything but location

      // dont place a marker if there is one already there
      if (marker_id != "loc") {
          if (marker.position.latitude == _curr_location.position.latitude &&
              marker.position.longitude == _curr_location.position.longitude) {
            leave = true;

            if(icon_id == "medal"){
                // update icon in app
                _markers.update(marker_id,
                                (existingValue) => marker.copyWith(iconParam:  marker_icons[icon_id]));



                // replace shared preferences marker
                replace_marker_prefs(marker.position.latitude,
                                     marker.position.longitude,
                                     marker_id,
                                     "medal");

                setState(() {
                    _markers = _markers;
                });

                return;
            }
          }

      }


    });

    if(!leave) {
      // add marker to make, using
      setState(() {
        debugPrint("${_markers.length}");
        _markers.addAll({ "${_markers.length}":
        Marker(markerId: MarkerId("${_markers.length}"),
          position: _curr_location.position,
          icon: marker_icons[icon_id],
        )
        });
      });

      add_marker_prefs(_curr_location.position.latitude,
          _curr_location.position.longitude,
          icon_id);
    }
  }

  // utility function to send location data to glove
  // if no connection exists, does not do anything
  void send_loc_data()
  {
    if(_bl_serial_connection == null) {
      return;
    }

    if(_bl_serial_connection.isConnected){
      var loc_msg = """lat${_curr_location.position.latitude},
                    lng${_curr_location.position.latitude}""";


      send_message_persistent(loc_msg);
    }

  }


  void _stop_monitoring_devices()
  {
    _stream_subscriptions[0].pause();
  }

  void _start_monitoring_devices()
  {
    _stream_subscriptions[0].resume();
  }

  void log_data(DateTime date, GloveData glove_data)
  {
    // log in file string

    // date / time section
    String log_line= "${date.day}.${date.month}.${date.year},${date.hour}:"
                      "${date.minute}:${date.second},";

    // data section
    log_line += "${glove_data.heart_rate},${glove_data.stress_level},";
    log_line += "${glove_data.steps},${glove_data.acceleration},";
    log_line += "${_curr_location.position.latitude},${_curr_location.position.longitude},";
    log_line += "${glove_data.stress_alarm},${glove_data.inact_alarm},";
    log_line += "${glove_data.challenge},${glove_data.comfort},";

    widget.storage.write_data(log_line);
  }

  // disposes of bluetooth connection
  void dispose_bl_connection()
  {

    if(_bl_serial_connection != null && _bl_serial_connection.isConnected ) {
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
  
  // sends message with persistent catch, with num of tries
  void send_message_persistent(String message, [int tries = 5 ]){
    // do not attempt to send
    if(tries == 0 )
      return;

    try{
      _sendMessage(message);
    } catch(e) {
      debugPrint("Message send error!");
      // try again
      send_message_persistent(message, tries - 1);
    }
    
  }
  

}


