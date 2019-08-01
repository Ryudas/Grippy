// Defines loading of markers and other related events
import 'dart:async' show Future;

import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // for google maps

Map<String, Marker> process_markers()
{
    // map temporary markers
    var temp_marker = <String, Marker>{};
    // map of marker icons
    var marker_icons = process_icons();



    temp_marker.addAll({ "one": Marker( markerId: MarkerId("one"),
                                        position: LatLng(52.011034,4.357725),
                                ),
                         "two": Marker( markerId: MarkerId("two"),
                                        position: LatLng(52.0127,4.3559),
                                ),
                         "three": Marker(markerId: MarkerId("three"),
                                          position: LatLng(52.0095,4.3588),
                                  ),
    });

    return(temp_marker);
}

// processes all the icons of the markers
Map <String, BitmapDescriptor>process_icons() 
{
  var temp_icons = <String, BitmapDescriptor>{};
  var temp =  AssetImage("assets/medal/icon.png");
  temp_icons.addAll({ "medal": load_asset()
  });


  return(temp_icons);
}

// will load asset in a Bitmap descriptor
Future<BitmapDescriptor> load_asset( String asset_name) async
{
    var temp = await BitmapDescriptor.fromAssetImage(ImageConfiguration(),
                                                     "assets/$asset_name/icon.png"
                     );
    
    return(temp);
}