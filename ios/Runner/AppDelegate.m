#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
// import for google maps.
#include "GoogleMaps/GoogleMaps.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];

    
    // Adding Google maps API key
    [GMSServices provideAPIKey: @"***REMOVED***"];
    
    //show status bar again
    UIApplication.sharedApplication.statusBarHidden = false;
    
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
