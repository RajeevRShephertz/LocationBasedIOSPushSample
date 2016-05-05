/*****************************************************************
 *  App42PushManager.h
 *  App42PushSample
 *
 *  Created by Rajeev Ranjan on 03/03/15.
 *  Copyright (c) 2015 Rajeev Ranjan. All rights reserved.
 ****************************************************************/

/*****************************************************************

 This plug-in can be used to handle geo based push sent from the App42 Cloud.
 Plug-in uses CoreLocation framework in optimized way. To use the plug-in you 
 need to add CoreLocation.framework.
 Also you have to add "NSLocationAlwaysUsageDescription" key to your project's 
 info.plist file and enable Background Modes for Remote notifications from 
 Capabilities section under project Targets in the Xcode.
 
*****************************************************************/

 
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface App42PushManager : NSObject<CLLocationManagerDelegate>
{
    CLLocationManager *locManager;
}

@property(nonatomic,retain) CLLocationManager *locManager;

/***
 * Singleton instance
 */
+(instancetype)sharedManager;

/****
 * Call to trigger the plugin
 */
-(void)handleGeoBasedPush:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
-(void)sendGeoFencingPush:(CLRegion*)region forEvent:(NSString*)event;

@end
