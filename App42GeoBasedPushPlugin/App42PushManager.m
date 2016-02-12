//
//  App42PushManager.m
//  App42PushSample
//
//  Created by Rajeev Ranjan on 03/03/15.
//  Copyright (c) 2015 Rajeev Ranjan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "App42PushManager.h"


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

/**
 * Keys for multi-location push payload
 */
#define APP42_MAPLOCATION       @"app42_mapLocation"
#define APP42_LAT               @"lat"
#define APP42_LNG               @"lng"
#define APP42_RADIUS            @"radius"

typedef void (^App42FetchCompletion)(UIBackgroundFetchResult);

@interface App42PushManager ()
{
    App42FetchCompletion fetchCompletion;
}

@property(nonatomic) NSDictionary *pushMessageDict;
@property (nonatomic, strong)NSMutableArray* bgTaskIdList;
@property (assign) UIBackgroundTaskIdentifier lastTaskId;

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
    NSString *geoBaseType = [userInfo objectForKey:APP42_GEOBASE];
    if (geoBaseType)
    {
        NSLog(@"%s...Processing geo-based push",__func__);
        self.pushMessageDict = [userInfo copy];
        fetchCompletion = completionHandler;
        [self beginNewBackgroundTask];
        locManager.delegate = self;
        [locManager startUpdatingLocation];
    }
    completionHandler(UIBackgroundFetchResultNewData);
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
    
    NSString *geoBaseType = [_pushMessageDict objectForKey:APP42_GEOBASE];
    if ([geoBaseType isEqualToString:APP42_COORDINATEBASE])
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
    else if ([geoBaseType isEqualToString:APP42_ADDRESSBASE])
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
    NSString *multiLocations = [_pushMessageDict objectForKey:APP42_MAPLOCATION];
    if (multiLocations) {
        NSError *error = nil;
        NSArray *regions = [NSJSONSerialization JSONObjectWithData:[multiLocations dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
        //NSLog(@"MapDict = %@",regions);
        for (NSDictionary *regionCoordinates in regions) {
            CLLocationCoordinate2D center;
            center.longitude = [[regionCoordinates objectForKey:APP42_LNG] doubleValue];
            center.latitude  = [[regionCoordinates objectForKey:APP42_LAT] doubleValue];
           
            /*NSLog(@"Lat = %lf",[[regionCoordinates objectForKey:APP42_LAT] doubleValue]);
            NSLog(@"Lng = %lf",[[regionCoordinates objectForKey:APP42_LNG] doubleValue]);
            NSLog(@"Radius = %lf",[[regionCoordinates objectForKey:APP42_RADIUS] doubleValue]);*/
            
            CLLocationDistance radius = [[regionCoordinates objectForKey:APP42_RADIUS] doubleValue]*1000;
            
            CLCircularRegion *region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:@"App42Fence"];
            isInTheRegion = [region containsCoordinate:newLocation.coordinate];
            if (isInTheRegion) {
                break;
            }
        }
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
    locNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:10];
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
