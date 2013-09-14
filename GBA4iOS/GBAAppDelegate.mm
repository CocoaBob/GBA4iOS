//
//  GBAAppDelegate.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAAppDelegate.h"
#import "GBASettingsViewController.h"

#import <SSZipArchive/minizip/SSZipArchive.h>

@implementation GBAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"GBAResources" ofType:@"bundle"];
    NSBundle *resourceBundle = [NSBundle bundleWithPath:resourceBundlePath];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:resourceBundle];
    self.window.rootViewController = [storyboard instantiateInitialViewController];
    
    [self.window makeKeyAndVisible];
    
    if ([self.window respondsToSelector:@selector(setTintColor:)])
    {
        self.window.tintColor = [UIColor purpleColor];
        [[UISwitch appearance] setOnTintColor:[UIColor purpleColor]]; // Apparently UISwitches don't inherit tint color from superview
    }
    
    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    
    if (url)
    {
        [self moveROMAtURLToDocumentsDirectory:url];
    }
    
    [GBASettingsViewController registerDefaults];
    
    return YES;
}

-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([url isFileURL])
    {
        [self moveROMAtURLToDocumentsDirectory:url];
    }
    return YES;
}

#pragma mark - Copying ROMs

- (void)moveROMAtURLToDocumentsDirectory:(NSURL *)url
{
    NSString *filepath = [url path];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    DLog(@"%@", [url absoluteString]);
    
    if ([[[filepath pathExtension] lowercaseString] isEqualToString:@"zip"])
    {
        [SSZipArchive unzipFileAtPath:filepath toDestination:documentsDirectory];
        [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
    }
    else
    {
        NSString *filename = [filepath lastPathComponent];
        [[NSFileManager defaultManager] moveItemAtPath:filepath toPath:[documentsDirectory stringByAppendingPathComponent:filename] error:nil];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
