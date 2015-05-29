//
//  ViewController.h
//  App42PushNotificationSample
//
//  Created by Rajeev Ranjan on 29/07/13.
//  Copyright (c) 2013 ShepHertz Technologies Pvt Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Shephertz_App42_iOS_API/Shephertz_App42_iOS_API.h"

@interface ViewController : UIViewController
{
    IBOutlet UILabel *pushNotification;
    IBOutlet UITextView *responseView;
    IBOutlet UITextField *userNameTextField;
    IBOutlet UIActivityIndicatorView *indicator;
    NSMutableArray *docIDArray;
    StorageService *storageService;
}

@property(nonatomic,retain) NSString *deviceToken;

-(IBAction)sendPushButtonAction:(id)sender;
-(void)updatePushMessageLabel:(NSString*)message;
-(IBAction)registerDeviceToken:(id)sender;


@end
