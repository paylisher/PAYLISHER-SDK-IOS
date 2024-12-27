//
//  AppDelegate.m
//  PaylisherObjCExample
//
//  Created by Manoel Aranda Neto on 23.10.23.
//

#import "AppDelegate.h"
#import <Paylisher/Paylisher.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (void)receiveTestNotification {
    NSLog(@"received");
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(receiveTestNotification)
            name:PaylisherSDK.didStartNotification
            object:nil];

    PaylisherConfig *config = [[PaylisherConfig alloc] apiKey:@"_6SG-F7I1vCuZ-HdJL3VZQqjBlaSb1_20hDPwqMNnGI"];
    config.preloadFeatureFlags = YES;
    [[PaylisherSDK shared] debug:YES];
    [[PaylisherSDK shared] setup:config];
    
    NSString *event = @"theEvent";
    NSString *distinctId = @"theCustomDistinctId";
    NSDictionary *properties = @{@"source": @"iOS App", @"state": @"running"};
    NSDictionary *userProperties = @{@"userAlive": @YES, @"userAge": @50};
    NSDictionary *userPropertiesSetOnce = @{@"signupDate": @"2024-10-16"};
    NSDictionary *groups = @{@"groupName": @"developers"};

    [[PaylisherSDK shared] captureWithEvent:event
                               distinctId:distinctId
                               properties:properties
                            userProperties:userProperties
                    userPropertiesSetOnce:userPropertiesSetOnce
                                   groups:groups
    ];
    
    [[PaylisherSDK shared] captureWithEvent:event
                               properties:properties
                            userProperties:userProperties
                    userPropertiesSetOnce:userPropertiesSetOnce
    ];
    
//    NSLog(@"getDistinctId: %@", [[PaylisherSDK shared] getDistinctId]);
//    NSLog(@"getAnonymousId: %@", [[PaylisherSDK shared] getAnonymousId]);
//    
//    NSMutableDictionary *props = [NSMutableDictionary dictionary];
//    props[@"state"] = @"running";
//
//    NSMutableDictionary *userProps = [NSMutableDictionary dictionary];
//    userProps[@"userAge"] = @50;
//    
//    NSMutableDictionary *userPropsOnce = [NSMutableDictionary dictionary];
//    userPropsOnce[@"userAlive"] = @YES;
//    
//    NSMutableDictionary *groupProps = [NSMutableDictionary dictionary];
//    groupProps[@"groupName"] = @"theGroup";
//
//    NSMutableDictionary *registerProps = [NSMutableDictionary dictionary];
//    props[@"loggedIn"] = @YES;
//    [[PaylisherSDK shared] registerProperties:registerProps];
//    [[PaylisherSDK shared] unregisterProperties:@"test2"];
//    
//    [[PaylisherSDK shared] identify:@"my_new_id"];
//    [[PaylisherSDK shared] identifyWithDistinctId:@"my_new_id" userProperties:userProps];
//    [[PaylisherSDK shared] identifyWithDistinctId:@"my_new_id" userProperties:userProps userPropertiesSetOnce:userPropsOnce];
//    
//    
//    [[PaylisherSDK shared] optIn];
//    [[PaylisherSDK shared] optOut];
//    NSLog(@"isOptOut: %d", [[PaylisherSDK shared] isOptOut]);
//    NSLog(@"isFeatureEnabled: %d", [[PaylisherSDK shared] isFeatureEnabled:@"myFlag"]);
//    NSLog(@"getFeatureFlag: %@", [[PaylisherSDK shared] getFeatureFlag:@"myFlag"]);
//    NSLog(@"getFeatureFlagPayload: %@", [[PaylisherSDK shared] getFeatureFlagPayload:@"myFlag"]);
//    
//    [[PaylisherSDK shared] reloadFeatureFlags];
//    [[PaylisherSDK shared] reloadFeatureFlagsWithCallback:^(){
//        NSLog(@"called");
//    }];
//    
//    [[PaylisherSDK shared] capture:@"theEvent"];
//    [[PaylisherSDK shared] captureWithEvent:@"theEvent" properties:props];
//    [[PaylisherSDK shared] captureWithEvent:@"theEvent" properties:props userProperties:userProps];
//    [[PaylisherSDK shared] captureWithEvent:@"theEvent" properties:props userProperties:userProps userPropertiesSetOnce:userPropsOnce];
//    [[PaylisherSDK shared] captureWithEvent:@"theEvent" distinctId:@"custom_distinct_id" properties:props userProperties:userProps userPropertiesSetOnce:userPropsOnce groupProperties:groupProps];
//
//    [[PaylisherSDK shared] groupWithType:@"theType" key:@"theKey"];
//    [[PaylisherSDK shared] groupWithType:@"theType" key:@"theKey" groupProperties:groupProps];
//    
//    [[PaylisherSDK shared] alias:@"theAlias"];
//    
//    [[PaylisherSDK shared] screen:@"theScreen"];
//    [[PaylisherSDK shared] screenWithTitle:@"theScreen" properties:props];
    
//    [[PaylisherSDK shared] flush];
//    [[PaylisherSDK shared] reset];
//    [[PaylisherSDK shared] close];

//    PaylisherSDK *paylisher = [PaylisherSDK with:config];
//    
//    [paylisher capture:@"theCapture"];
    
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
