// Defines loading of markers and other related events
import 'package:flutter/cupertino.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  temp_icons.addAll({ "medal": BitmapDescriptor.fromAssetImage(
                                  ImageConfiguration(),

                               ),

  });


  return(temp_icons);
}

