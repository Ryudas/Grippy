// Defines loading of markers and other related events (such as data storage)
import 'dart:async' show Future;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

// for google maps
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

// shared preferences for file loading
import 'package:shared_preferences/shared_preferences.dart';


// function to process markers for the map display, given a shared pref
Future<Map<String, Marker>> process_markers(BuildContext context) async
{
    // map temporary markers
    var temp_marker = <String, Marker>{};
    // map of marker icons
    var marker_icons = await load_icons();

    // get shared preferences instance object for our markers
    SharedPreferences marker_prefs = await SharedPreferences.getInstance();
    // get number of saved markers (zero if none exist)
    var num_markers = (marker_prefs.getInt("counter") ?? 0);

    for(int i = 0; i < num_markers; i++)
    {
         // get each marker saved object and save new marker
         // each ob has lat long, and string denoting which icon
         var marker_list = marker_prefs.getStringList("${i}");
         temp_marker["${i}"] = Marker( markerId: MarkerId("${i}"),
                                       position: LatLng(
                                           double.parse(marker_list[0]),
                                           double.parse(marker_list[1])
                                       ),
                                       icon: marker_icons[marker_list[2]],
                               );                      
    }


    return(temp_marker);
}


// will load asset in a Bitmap descriptor
Future<BitmapDescriptor> load_asset(String asset_name) async
{
   return(BitmapDescriptor.fromAssetImage(ImageConfiguration(bundle: rootBundle),
                                          "assets/$asset_name/4.0x/icon.png",
                                          bundle: rootBundle
         ));

}

// loads all icon assets available to app, asynchronously
Future<Map<String, BitmapDescriptor>> load_icons() async
{
  var marker_icons = <String, BitmapDescriptor>{};

  marker_icons.addAll({"medal": await load_asset("medal"),
                       "fist_red": await load_asset("fist_red"),
                       "fist_green": await load_asset("fist_green"),
                       "fist_yellow": await load_asset("fist_yellow"),
                      });

  return(marker_icons);
}

// add a marker to shared preferences
// icon string can be "medal, fist_{red, green, yellow}"
Future<bool> add_marker_prefs (double lat, double lng, String icon) async
{

  // get shared preferences instance object for our markers
  SharedPreferences marker_prefs = await SharedPreferences.getInstance();
  // get number of saved markers (zero if none exist)
  var num_markers = (marker_prefs.getInt("counter") ?? 0);
  var temp_marker = <String>[];
  temp_marker.add("${lat}");
  temp_marker.add("${lng}");
  temp_marker.add(icon);
  // index is still num markers, since theyre zero indexed
  bool res = await marker_prefs.setStringList("${num_markers}",temp_marker);
  res |=  await marker_prefs.setInt("counter", num_markers + 1);

  // if failed will have to do again
  return(res);

}


// replace a marker in shared preferences
// icon string can be "medal, fist_{red, green, yellow}"
Future<bool> replace_marker_prefs (double lat, double lng, String marker_id, String replacing_icon) async
{

  // get shared preferences instance object for our markers
  SharedPreferences marker_prefs = await SharedPreferences.getInstance();
  var temp_marker = <String>[];
  temp_marker.add("${lat}");
  temp_marker.add("${lng}");
  temp_marker.add(replacing_icon);
  // index is still num markers, since theyre zero indexed
  bool res = await marker_prefs.setStringList(marker_id,temp_marker);


  // if failed will have to do again
  return(res);

}


// tries to remove all markers in shared preferences
void  remove_all_markers_prefs() async
{
  // get shared preferences instance object for our markers
  SharedPreferences marker_prefs = await SharedPreferences.getInstance();
  // get number of saved markers (zero if none exist)
  var num_markers = (marker_prefs.getInt("counter") ?? 0);

  for(int i = 0; i < num_markers; i++)
  {
    // get each marker saved object and save new marker
    // each ob has lat long, and string denoting which icon
    bool res = await marker_prefs.remove("${i}");
    // get number of saved markers (zero if none exist)
    var temp = marker_prefs.getInt("counter");

    if (res) await marker_prefs.setInt("counter", temp - 1 );
  }

}

// removes particular marker in shared preferences
void remove_marker_prefs(String marker_id) async  
{ 
  // get shared preferences instance object for our markers
  SharedPreferences marker_prefs = await SharedPreferences.getInstance();
  // get number of saved markers (zero if none exist)
  var num_markers = (marker_prefs.getInt("counter") ?? 0);


    // get each marker saved object and save new marker
    // each ob has lat long, and string denoting which icon
    bool res = await marker_prefs.remove(marker_id);
    // get number of saved markers (zero if none exist)
    var temp = marker_prefs.getInt("counter");

    if (res) await marker_prefs.setInt("counter", temp - 1 );
  }
}