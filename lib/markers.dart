// Defines loading of markers and other related events
import 'dart:async' show Future;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // for google maps
import 'package:flutter/services.dart' show rootBundle;

Future<Map<String, Marker>> process_markers(BuildContext context) async
{
    // map temporary markers
    var temp_marker = <String, Marker>{};
    // map of marker icons
    var marker_icons = <String, BitmapDescriptor>{};

    marker_icons.addAll({"medal": await load_asset("medal"),
                         "fist_red": await load_asset("fist_red"),
                         "fist_green": await load_asset("fist_green"),
                         "fist_yellow": await load_asset("fist_yellow"),
    });

    temp_marker.addAll({ "one": Marker( markerId: MarkerId("one"),
                                        position: LatLng(52.011034,4.357725),
                                        icon: marker_icons["fist_red"],
                                ),
                         "two": Marker( markerId: MarkerId("two"),
                                        position: LatLng(52.0127,4.3559),
                                        icon: marker_icons["fist_green"],
                                ),
                         "three": Marker(markerId: MarkerId("three"),
                                         position: LatLng(52.0095,4.3588),
                                         icon: marker_icons["fist_yellow"],

                                  ),
    });

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