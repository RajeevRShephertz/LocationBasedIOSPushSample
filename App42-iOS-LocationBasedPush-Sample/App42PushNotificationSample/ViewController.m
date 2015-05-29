//
//  ViewController.m
//  App42PushNotificationSample
//
//  Created by Rajeev Ranjan on 29/07/13.
//  Copyright (c) 2013 ShepHertz Technologies Pvt Ltd. All rights reserved.
//

#import "ViewController.h"


@interface ViewController ()
{
    NSString *userName;
}
@end

@implementation ViewController
@synthesize deviceToken;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    indicator.hidden = YES;
    storageService = [App42API buildStorageService];
    userName = @"";
    userNameTextField.text = @"";
}


-(IBAction)registerDeviceToken:(id)sender 
{
    
    if (userNameTextField.isFirstResponder)
    {
        [userNameTextField resignFirstResponder];
    }
    indicator.hidden = NO;
    [indicator startAnimating];
    userName = userNameTextField.text;
    userName = [userName stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (userName.length)
    {
        @try
        {
            /***
             * Registering Device Token to App42 Cloud API
             */
            PushNotificationService *pushObj=[App42API buildPushService];
            [pushObj registerDeviceToken:deviceToken withUser:userName completionBlock:^(BOOL success, id responseObj, App42Exception *exception) {
                if (success) {
                    PushNotification *push = (PushNotification*)responseObj;
                    responseView.text = push.strResponse;
                }
                else
                {
                    NSLog(@"Reason = %@",exception.reason);
                    responseView.text = exception.reason;
                }
            }];
            
            [pushObj release];
        }
        @catch (App42Exception *exception)
        {
            NSLog(@"Reason = %@",exception.reason);
            responseView.text = exception.reason;
        }
        @finally
        {
            
        }
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please, enter the user name" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [self.view addSubview:alertView];
        [alertView show];
    }

    [indicator stopAnimating];
    indicator.hidden = YES;
}

- (IBAction)unregisterForPush:(id)sender
{
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
}


-(IBAction)sendPushButtonAction:(id)sender
{
    if (userNameTextField.isFirstResponder)
    {
        [userNameTextField resignFirstResponder];
    }
    userName = userNameTextField.text;
    userName = [userName stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (userName.length)
    {
        [self sendPush:@"Hello, Ur Friend has poked you!" toUser:userName];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please, enter the user name" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [self.view addSubview:alertView];
        [alertView show];
    }
}

-(void)sendPush:(NSString*)message toUser:(NSString*)_userName
{
    @try
    {
        indicator.hidden = NO;
        [indicator startAnimating];
        
        
        //NSDictionary *alertDict = [NSDictionary dictionaryWithObjectsAndKeys:@"GAME_PLAY_REQUEST_FORMAT",@"loc-key",[NSArray arrayWithObjects:@"Hello", nil],@"loc-args", nil];
        
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setObject:message forKey:@"alert"];
        [dictionary setObject:@"default" forKey:@"sound"];
        [dictionary setObject:[NSNumber numberWithInt:1] forKey:@"badge"];
        //[dictionary setObject:[NSNumber numberWithInt:1] forKey:@"content-available"];
        
        PushNotificationService *pushObj=[App42API buildPushService];
        [pushObj sendPushMessageToUser:@"ahdhdhshajaj" withMessageDictionary:dictionary completionBlock:^(BOOL success, id responseObj, App42Exception *exception) {
            if (success) {
                PushNotification *push = (PushNotification*)responseObj;
                responseView.text = push.strResponse;
            }
            else
            {
                NSLog(@"Reason = %@",exception.reason);
                responseView.text = exception.reason;
            }
            
            [indicator stopAnimating];
            indicator.hidden = YES;
            
            [pushObj release];
        }];
        
        
    }
    @catch (App42Exception *exception)
    {
        NSLog(@"Reason = %@",exception.reason);
        responseView.text = exception.reason;
    }
    @finally
    {
        
    }
}


-(void)subscribeChannel:(NSString*)channelName toUser:(NSString*)_userName
{
    @try
    {
        PushNotificationService *pushObj=[App42API buildPushService];
        [pushObj subscribeToChannel:channelName userName:userName deviceToken:deviceToken completionBlock:^(BOOL success, id responseObj, App42Exception *exception) {
            if (success) {
                PushNotification *push = (PushNotification*)responseObj;
                responseView.text = push.strResponse;
            }
            else
            {
                NSLog(@"Reason = %@",exception.reason);
                responseView.text = exception.reason;
            }
            [pushObj release];
        }];
    }
    @catch (App42Exception *exception)
    {
        NSLog(@"Reason = %@",exception.reason);
    }
    @finally
    {
        
    }

}

-(void)sendPush:(NSString*)message toChannel:(NSString*)channelName
{
    @try
    {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [dictionary setObject:message forKey:@"alert"];
        [dictionary setObject:@"default" forKey:@"sound"];
        [dictionary setObject:@"2" forKey:@"badge"];
        
        PushNotificationService *pushObj=[App42API buildPushService];
        [pushObj sendPushMessageToChannel:channelName withMessageDictionary:dictionary completionBlock:^(BOOL success, id responseObj, App42Exception *exception) {
            if (success) {
                PushNotification *push = (PushNotification*)responseObj;
                responseView.text = push.strResponse;
            }
            else
            {
                NSLog(@"Reason = %@",exception.reason);
                responseView.text = exception.reason;
            }
            [pushObj release];
        }];
    }
    @catch (App42Exception *exception)
    {
        NSLog(@"Reason = %@",exception.reason);
    }
    @finally
    {
        
    }
    
}


-(void)updatePushMessageLabel:(NSString*)message
{
    pushNotification.text = message;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




@end
