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

    marker_icons["medal"] = await load_asset(context, "medal");


    temp_marker.addAll({ "one": Marker( markerId: MarkerId("one"),
                                        position: LatLng(52.011034,4.357725),

                                ),
                         "two": Marker( markerId: MarkerId("two"),
                                        position: LatLng(52.0127,4.3559),
                                ),
                         "three": Marker(markerId: MarkerId("three"),
                                         position: LatLng(52.0095,4.3588),
                                         icon: marker_icons["medal"]
                                  ),
    });

    return(temp_marker);
}


// will load asset in a Bitmap descriptor
Future<BitmapDescriptor> load_asset(BuildContext context, String asset_name) async
{
   return(BitmapDescriptor.fromAssetImage(createLocalImageConfiguration(context),
                                          "assets/$asset_name/icon.png",
                                          bundle: rootBundle
         ));

}