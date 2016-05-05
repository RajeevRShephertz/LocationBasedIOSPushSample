//
//  App42PushManager.m
//  App42PushSample
//
//  Created by Rajeev Ranjan on 03/03/15.
//  Copyright (c) 2015 Rajeev Ranjan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "App42PushManager.h"
#import <Shephertz_App42_iOS_API/Shephertz_App42_iOS_API.h>

#define APP42_GEOBASE           @"app42_geoBase"
#define APP42_ADDRESSBASE       @"addressBase"
#define APP42_COORDINATEBASE    @"coordinateBase"
#define APP42_COUNTRYCODE       @"app42_countryCode"
#define APP42_COUNTRYNAME       @"app42_countryName"
#define APP42_STATENAME         @"app42_stateName"
#define APP42_CITYNAME          @"app42_cityName"
#define APP42_DISTANCE          @"app42_distance"

#define APP42_PUSH_MESSAGE      @"app42_message"
#define APP42_LONGITUDE         @"app42_lng"
#define APP42_LATITUDE          @"app42_lat"
#define APP42_LOC_IDENTIFIER    @"APP42_LOC_IDENTIFIER"
#define APP42_FENCEDETAILS      @"app42_fencedetails"

/**
 * Keys for Geo-Fence push payload
 */
#define APP42_GEOFENCEID        @"app42_geoFenceId"
#define APP42_GEOFENCEDATA      @"_App42GeoFenceData"
#define APP42_ENTRY             @"app42_entry"
#define APP42_EXIT              @"app42_exit"

/**
 * Keys for Geo-Fence entry-exit response keys
 */

#define APP42_ISVALID   @"isValid"

/**
 * Keys for multi-location push payload
 */
#define APP42_MAPLOCATION       @"app42_mapLocation"
#define APP42_LAT               @"lat"
#define APP42_LNG               @"lng"
#define APP42_RADIUS            @"radius"

/**
 * Keys for push campaign
 */
#define APP42_GEOCAMPAIGN       @"_App42GeoCampaign"
#define APP42_CAMPAIGNNAME      @"_App42CampaignName"
#define APP42_GEOFENCECOORDINATES  @"_App42GeoFenceCoordinates"
#define APP42_GEOTARGETCOORDINATES @"_App42GeoTargetCoordinates"

typedef enum : NSUInteger {
    kAPP42GEOCAMPAIGN,
    kAPP42GEONORMAL,
    kAPP42GEOFENCE,
    kAPP42NONE,
} App42PushType;

typedef enum : NSUInteger {
    kAPP42COORDINATE,
    kAPP42ADDRESS,
    kAPP42GEONONE,
} App42GeoType;

typedef void (^App42FetchCompletion)(UIBackgroundFetchResult);

@interface App42PushManager ()
{
    App42FetchCompletion fetchCompletion;
}

@property(nonatomic) NSDictionary *pushMessageDict;
@property(nonatomic) NSDictionary *app42GeoCampaign;
@property(nonatomic, strong)NSMutableArray* bgTaskIdList;
@property(assign) UIBackgroundTaskIdentifier lastTaskId;
@property(assign) App42PushType pushType;
@property(assign) App42GeoType geoType;

-(void)requestToAccessLocation;
-(BOOL)isApp42GeoBasedPush:(NSDictionary*)userInfo;
-(BOOL)isEligibleForNotificationWithCoordinate:(CLLocation*)newLocation;
-(void)showNotificationIfEligibleWithAddress:(CLLocation*)newLocation;
-(void)scheduleNotificationWithMessage:(NSString*)pushMessage;

@end

@implementation App42PushManager

@synthesize locManager;

+(instancetype)sharedManager
{
    static App42PushManager *_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        [self requestToAccessLocation];
        _bgTaskIdList = [[NSMutableArray alloc] initWithCapacity:0];
        _lastTaskId = UIBackgroundTaskInvalid;
    }
    return self;
}

-(void)requestToAccessLocation
{
    NSLog(@"%s",__func__);
    if (!locManager)
    {
        NSLog(@"Creating location manager");
        locManager= [[CLLocationManager alloc] init];
    }
    
    NSLog(@"Location manager created!!!");
    locManager.delegate = self;
    locManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    locManager.distanceFilter = kCLDistanceFilterNone;
    
    // request authorization to track the user’s location
    [locManager requestAlwaysAuthorization];
}

-(void)handleGeoBasedPush:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSString *geoBaseType = nil;
    [self getCampaignType:userInfo];
    if (self.pushType == kAPP42GEOCAMPAIGN)
    {
        NSString *geoCampInfo = [userInfo objectForKey:APP42_GEOCAMPAIGN];
        NSError *error = nil;
        NSDictionary *geoCampDict = [NSJSONSerialization JSONObjectWithData:[geoCampInfo dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
        self.app42GeoCampaign = [geoCampDict copy];
        geoBaseType = [_app42GeoCampaign objectForKey:APP42_GEOBASE];
    }
    else if (self.pushType == kAPP42GEOFENCE)
    {
        [self startGeoFenceMonitoring:userInfo];
    }
    else
    {
        geoBaseType = [userInfo objectForKey:APP42_GEOBASE];
    }
    [self getGeoBaseType:geoBaseType];
    if (geoBaseType)
    {
        self.pushMessageDict = [userInfo copy];
        fetchCompletion = completionHandler;
        [self beginNewBackgroundTask];
        locManager.delegate = self;
        [locManager startUpdatingLocation];
    }
    if (completionHandler) {
        completionHandler(UIBackgroundFetchResultNewData);
    }
}

-(void)getCampaignType:(NSDictionary*)userInfo
{
    NSString *geoCampInfo = [userInfo objectForKey:APP42_GEOCAMPAIGN];
    NSString *geoFenceInfo = [userInfo objectForKey:APP42_GEOFENCECOORDINATES];
    if (geoCampInfo) {
        self.pushType = kAPP42GEOCAMPAIGN;
    }
    else if(geoFenceInfo)
    {
        self.pushType = kAPP42GEOFENCE;
    }
    else
    {
        self.pushType = kAPP42GEONORMAL;
    }
}

-(void)getGeoBaseType:(NSString*)geoBaseType
{
    if ([geoBaseType isEqualToString:APP42_COORDINATEBASE]) {
        self.geoType = kAPP42COORDINATE;
    }
    else if ([geoBaseType isEqualToString:APP42_COORDINATEBASE]) {
        self.geoType = kAPP42ADDRESS;
    }
    else
    {
        self.geoType = kAPP42GEONONE;
    }
}

-(void)startGeoFenceMonitoring:(NSDictionary*)fenceInfo
{
    NSError *error1 = nil;
    NSString *fenceCoordinatesStr = [fenceInfo objectForKey:APP42_GEOFENCECOORDINATES];
    NSArray *fenceCoordinates = [NSJSONSerialization JSONObjectWithData:[fenceCoordinatesStr dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error1];
    
    NSError *error2 = nil;
    NSString *fenceDataStr = [fenceInfo objectForKey:APP42_GEOFENCEDATA];
    NSDictionary *fenceData = [NSJSONSerialization JSONObjectWithData:[fenceDataStr dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error2];
    for (NSDictionary *fence in fenceCoordinates) {
        CLLocationCoordinate2D center;
        center.longitude = [[fence objectForKey:APP42_LONGITUDE] doubleValue];
        center.latitude  = [[fence objectForKey:APP42_LATITUDE] doubleValue];

        CLLocationDistance radius = [[fence objectForKey:APP42_DISTANCE] doubleValue]*1000;
        NSString *fenceId = [NSString stringWithFormat:@"%@$$$%d",[fenceData objectForKey:APP42_CAMPAIGNNAME],[[fence objectForKey:APP42_GEOFENCEID] intValue]];
        // Initialize Region to Monitor
        CLRegion *region = [[CLRegion alloc] initCircularRegionWithCenter:center radius:radius identifier:fenceId];
        region.notifyOnEntry = [[fenceData objectForKey:APP42_ENTRY] boolValue];
        region.notifyOnExit = [[fenceData objectForKey:APP42_EXIT] boolValue];
        //Save fence data for future use
        [self addFenceDetails:[fenceData objectForKey:APP42_CAMPAIGNNAME] forFence:fenceId];
        // Start Monitoring Region
        [self.locManager startMonitoringForRegion:region];
        NSLog(@"End");
    }
}

-(void)stopMonitoringForFenceWithID:(CLRegion*)regi
{
    
}

-(void)addFenceDetails:(NSString*)campaignName forFence:(NSString*)fenceId
{
    NSMutableDictionary *fenceDetails = [[[NSUserDefaults standardUserDefaults] objectForKey:APP42_FENCEDETAILS] mutableCopy];
    if (!fenceDetails && fenceDetails.count) {
        [fenceDetails setObject:campaignName forKey:fenceId];
        [[NSUserDefaults standardUserDefaults] setObject:fenceDetails forKey:APP42_FENCEDETAILS];
        
    } else {
        NSDictionary *fenceDetailsDict = [NSDictionary dictionaryWithObjectsAndKeys:campaignName,fenceId, nil];
        [[NSUserDefaults standardUserDefaults] setObject:fenceDetailsDict forKey:APP42_FENCEDETAILS];
    }
}

-(NSString*)getFenceDetails:(NSString*)fenceId
{
    NSMutableDictionary *fenceDetails = [[[NSUserDefaults standardUserDefaults] objectForKey:APP42_FENCEDETAILS] mutableCopy];
    return [fenceDetails objectForKey:fenceId];
}

- (void)startShowingNotifications
{
    
}

#pragma mark- Location Manager Delegates
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    // check status to see if we’re authorized
    BOOL canUseLocationNotifications = (status == kCLAuthorizationStatusAuthorizedAlways);
    if (canUseLocationNotifications)
    {
        NSLog(@"%s   SUCCESS",__func__);
    }
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [locManager stopUpdatingLocation];
    locManager.delegate = nil;
    CLLocation *newLocation = [locations lastObject];
    
    if (self.geoType == kAPP42COORDINATE)
    {
        if ([self isEligibleForNotificationWithCoordinate:newLocation])
        {
            [self scheduleNotificationWithMessage:[_pushMessageDict objectForKey:APP42_PUSH_MESSAGE]];
        }
        else
        {
            NSLog(@".....Not in the region");
        }
        [self endAllBackgroundTasks];
    }
    else if (self.geoType == kAPP42ADDRESS)
    {
        [self showNotificationIfEligibleWithAddress:newLocation];
    }
    else
    {
        [self endAllBackgroundTasks];
    }
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"%s",__func__);
     [locManager stopUpdatingLocation];
    locManager.delegate = nil;
    [self endAllBackgroundTasks];
}


- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self scheduleNotificationWithMessage:[NSString stringWithFormat:@"Entered the region...%@",region.identifier]];
    [self sendGeoFencingPush:region forEvent:@"entry"];
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self scheduleNotificationWithMessage:[NSString stringWithFormat:@"Exiting the region...%@",region.identifier]];
    [self sendGeoFencingPush:region forEvent:@"exit"];
}

-(void)sendGeoFencingPush:(CLRegion*)region forEvent:(NSString*)event
{
    NSString *campaignName = [self getFenceDetails:region.identifier];
    NSString *fenceId = [[region.identifier componentsSeparatedByString:@"$$$"] lastObject];
    EventService *eventService = [App42API buildEventService];
    NSMutableDictionary *geoProps = [NSMutableDictionary dictionaryWithObjectsAndKeys:fenceId,@"geoFenceId", campaignName,@"campaignName",event,@"event",nil];
    
    [eventService sendGeoFencingPush:[NSDictionary dictionary] geoProps:geoProps completionBlock:^(BOOL success, id responseObj, App42Exception *exception) {
        if (success) {
            NSLog(@"Fence tracked successfully");
            BOOL isValid = [self isFenceValid:responseObj];
            if (!isValid) {
                NSLog(@"Invalid Fence...stopping it");
                [self.locManager stopMonitoringForRegion:region];
            }
        }
        else
        {
            NSLog(@"Exception : %@",exception.reason);
        }
    }];
}


-(BOOL)isFenceValid:(id)responseDict
{
    BOOL isValid = NO;
    App42Response *app42Response = (App42Response*)responseDict;
    NSError *error = nil;
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:[app42Response.strResponse dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
    isValid = [[[[response objectForKey:@"app42"] objectForKey:@"response"] objectForKey:APP42_ISVALID] boolValue];
    return isValid;
}


#pragma mark- Others

-(BOOL)isApp42GeoBasedPush:(NSDictionary*)userInfo
{
    BOOL isGeoBasedPush = NO;
    NSString *geoBaseType = [userInfo objectForKey:APP42_GEOBASE];
    
    if (geoBaseType)
    {
        isGeoBasedPush = YES;
    }
    return isGeoBasedPush;
}


-(BOOL)isEligibleForNotificationWithCoordinate:(CLLocation*)newLocation
{
    BOOL isInTheRegion = NO;
    NSString *multiLocations = nil;
    NSArray *regions = nil;
    if (self.pushType == kAPP42GEOCAMPAIGN) {
        regions = [_app42GeoCampaign objectForKey:APP42_GEOTARGETCOORDINATES];
    }
    else
    {
        multiLocations = [_pushMessageDict objectForKey:APP42_MAPLOCATION];
        if (multiLocations) {
            NSError *error = nil;
            regions = [NSJSONSerialization JSONObjectWithData:[multiLocations dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
        }
    }
    if (regions) {
        
        for (NSDictionary *regionCoordinates in regions) {
            CLLocationCoordinate2D center;
            if ([regionCoordinates objectForKey:APP42_LNG]) {
                center.longitude = [[regionCoordinates objectForKey:APP42_LNG] doubleValue];
                center.latitude  = [[regionCoordinates objectForKey:APP42_LAT] doubleValue];
            }
            else
            {
                center.longitude = [[regionCoordinates objectForKey:APP42_LONGITUDE] doubleValue];
                center.latitude  = [[regionCoordinates objectForKey:APP42_LATITUDE] doubleValue];
            }
           
            /*NSLog(@"Lat = %lf",[[regionCoordinates objectForKey:APP42_LAT] doubleValue]);
            NSLog(@"Lng = %lf",[[regionCoordinates objectForKey:APP42_LNG] doubleValue]);
            NSLog(@"Radius = %lf",[[regionCoordinates objectForKey:APP42_RADIUS] doubleValue]);*/
            
            CLLocationDistance radius = [[regionCoordinates objectForKey:APP42_RADIUS] doubleValue]*1000;
            if (self.pushType == kAPP42GEOCAMPAIGN) {
                radius = [[regionCoordinates objectForKey:APP42_DISTANCE] doubleValue]*1000;
            }
           // NSLog(@"1..Lat=%f, Long = %f",newLocation.coordinate.latitude,newLocation.coordinate.longitude);
            //NSLog(@"2..Lat=%f, Long = %f",center.latitude,center.longitude);

            CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:@"App42Fence"];
            isInTheRegion = [region containsCoordinate:newLocation.coordinate];
            if (isInTheRegion) {
                break;
            }
        }
    }
    else if(self.pushType == kAPP42GEOCAMPAIGN)
    {
        CLLocationCoordinate2D center;
        center.longitude = [[_app42GeoCampaign objectForKey:APP42_LONGITUDE] doubleValue];
        center.latitude  = [[_app42GeoCampaign objectForKey:APP42_LATITUDE] doubleValue];
        CLLocationDistance radius = [[_app42GeoCampaign objectForKey:APP42_DISTANCE] doubleValue]*1000;
        CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:@"App42Fence"];
        isInTheRegion = [region containsCoordinate:newLocation.coordinate];
    }
    else
    {
        CLLocationCoordinate2D center;
        center.longitude = [[_pushMessageDict objectForKey:APP42_LONGITUDE] doubleValue];
        center.latitude  = [[_pushMessageDict objectForKey:APP42_LATITUDE] doubleValue];
        CLLocationDistance radius = [[_pushMessageDict objectForKey:APP42_DISTANCE] doubleValue]*1000;
        CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:@"App42Fence"];
        isInTheRegion = [region containsCoordinate:newLocation.coordinate];
    }
    
    return isInTheRegion;
}

-(void)showNotificationIfEligibleWithAddress:(CLLocation*)newLocation
{
    CLGeocoder *geoCoder = [[CLGeocoder alloc] init];
    [geoCoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        
        if (error == nil && [placemarks count] >0)
        {
            BOOL isEligible = NO;
            CLPlacemark *placemark = [placemarks lastObject];
            
            NSString *state, *countryName, *countryCode, *city;
            state = [placemark.administrativeArea uppercaseString];
            countryName = [placemark.country uppercaseString];
            countryCode = [placemark.ISOcountryCode uppercaseString];
            city = [placemark.locality uppercaseString];
            
            NSString *countryNameForPush,*countryCodeForPush,*stateForPush,*cityForPush;
            stateForPush = [[_pushMessageDict objectForKey:APP42_STATENAME] uppercaseString];
            countryNameForPush = [[_pushMessageDict objectForKey:APP42_COUNTRYCODE] uppercaseString];
            countryCodeForPush = [[_pushMessageDict objectForKey:APP42_COUNTRYCODE] uppercaseString];
            cityForPush = [[_pushMessageDict objectForKey:APP42_CITYNAME] uppercaseString];
            
            if ((countryNameForPush && [countryNameForPush isEqualToString:countryName]) || (countryCodeForPush && [countryCodeForPush isEqualToString:countryName]))
            {
                if (stateForPush && [stateForPush isEqualToString:state])
                {
                    if (cityForPush && [cityForPush isEqualToString:city])
                    {
                        isEligible = YES;
                    }
                    else if(!cityForPush)
                    {
                        isEligible = YES;
                    }
                }
                else if(!stateForPush)
                {
                    isEligible = YES;
                }
            }
            
            if (isEligible)
            {
                [self scheduleNotificationWithMessage:[_pushMessageDict objectForKey:APP42_PUSH_MESSAGE]];
            }
            else
            {
                NSLog(@"%s.....Not in the region",__func__);
            }
        }
        else
        {
            NSLog(@"%@", error.debugDescription);
        }
        [self endAllBackgroundTasks];
    }];
}

-(void)scheduleNotificationWithMessage:(NSString*)pushMessage
{
    NSLog(@"%s",__func__);
    UILocalNotification *locNotification = [[UILocalNotification alloc] init];
    locNotification.alertBody = pushMessage;
    locNotification.soundName = UILocalNotificationDefaultSoundName;
    locNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:1];
    locNotification.repeatInterval = 0;
    [[UIApplication sharedApplication] scheduleLocalNotification:locNotification];
}


#pragma mark- ------Background task management------

-(UIBackgroundTaskIdentifier)beginNewBackgroundTask
{
    UIApplication* application = [UIApplication sharedApplication];
    if ([application applicationState]!= UIApplicationStateBackground) {
        return UIBackgroundTaskInvalid;
    }
    
    UIBackgroundTaskIdentifier bgTaskId = UIBackgroundTaskInvalid;
    if([application respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)]){
        bgTaskId = [application beginBackgroundTaskWithExpirationHandler:^{
            NSLog(@"background task %lu expired", (unsigned long)bgTaskId);
        }];
        if ( self.lastTaskId == UIBackgroundTaskInvalid )
        {
            self.lastTaskId = bgTaskId;
            NSLog(@"started master task %lu", (unsigned long)self.lastTaskId);
        }
        else
        {
            //add this id to our list
             NSLog(@"started background task %lu", (unsigned long)bgTaskId);
            [self.bgTaskIdList addObject:@(bgTaskId)];
            NSLog(@"bgTaskIdList = %@",self.bgTaskIdList);
            [self endBackgroundTasks];
        }
    }
    return bgTaskId;
}

-(void)endBackgroundTasks
{
    [self endBGTasksFromList:NO];
}

-(void)endAllBackgroundTasks
{
    [self endBGTasksFromList:YES];
}

-(void)endBGTasksFromList:(BOOL)isEndAll
{
    //mark end of each of our background task
    UIApplication* application = [UIApplication sharedApplication];
    if([application respondsToSelector:@selector(endBackgroundTask:)]){
        NSUInteger count=self.bgTaskIdList.count;
        for ( NSUInteger i=(isEndAll?0:1); i<count; i++ )
        {
            UIBackgroundTaskIdentifier bgTaskId = [[self.bgTaskIdList objectAtIndex:0] integerValue];
            NSLog(@"ending background task with id -%lu", (unsigned long)bgTaskId);
            [application endBackgroundTask:bgTaskId];
            [self.bgTaskIdList removeObjectAtIndex:0];
        }
        if ( self.bgTaskIdList.count > 0 )
        {
            NSLog(@"kept background task id %@", [self.bgTaskIdList objectAtIndex:0]);
        }
        if ( isEndAll )
        {
            NSLog(@"no more background tasks running");
            [application endBackgroundTask:self.lastTaskId];
            self.lastTaskId = UIBackgroundTaskInvalid;
        }
        else
        {
            NSLog(@"kept master background task id %lu", (unsigned long)self.lastTaskId);
        }
    }
}

@end
