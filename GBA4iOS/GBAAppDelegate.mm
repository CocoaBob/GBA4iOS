//
//  GBAAppDelegate.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAAppDelegate.h"
#import "GBAEmulationViewController.h"
#import "GBASettingsViewController.h"
#import "GBAController.h"
#import "GBAROM.h"
#import "GBASplitViewController.h"

#import <SSZipArchive/minizip/SSZipArchive.h>

@implementation GBAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.tintColor = GBA4iOS_PURPLE_COLOR;
    
    [[UISwitch appearance] setOnTintColor:GBA4iOS_PURPLE_COLOR]; // Apparently UISwitches don't inherit tint color from superview
    
    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    
    if (url)
    {
        [self handleFileURL:url];
    }
    
    [GBASettingsViewController registerDefaults];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        
        GBAEmulationViewController *emulationViewController = [[GBAEmulationViewController alloc] init];
        
        self.window.rootViewController = emulationViewController;
    }
    else
    {
        GBASplitViewController *splitViewController = [[GBASplitViewController alloc] init];
        self.window.rootViewController = splitViewController;
    }
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([url isFileURL])
    {
        [self handleFileURL:url];
    }
    return YES;
}

- (void)handleFileURL:(NSURL *)url
{
    NSString *filepath = [url path];
    
    if ([[[filepath pathExtension] lowercaseString] isEqualToString:@"gbaskin"] || [[[filepath pathExtension] lowercaseString] isEqualToString:@"gbcskin"])
    {
        [self copySkinAtPathToDocumentsDirectory:filepath];
    }
    else if ([[[filepath pathExtension] lowercaseString] isEqualToString:@"zip"] ||
             [[[filepath pathExtension] lowercaseString] isEqualToString:@"gba"] ||
             [[[filepath pathExtension] lowercaseString] isEqualToString:@"gbc"] ||
             [[[filepath pathExtension] lowercaseString] isEqualToString:@"gb"])
    {
        [self copyROMAtPathToDocumentsDirectory:filepath];
    }
    
    // Empty Inbox folder
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[filepath stringByDeletingLastPathComponent] error:nil];
    for (NSString *filename in contents)
    {
        NSString *path = [[filepath stringByDeletingLastPathComponent] stringByAppendingPathComponent:filename];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

#pragma mark - Copying Files

- (void)copyROMAtPathToDocumentsDirectory:(NSString *)filepath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    if ([[[filepath pathExtension] lowercaseString] isEqualToString:@"zip"])
    {
        NSError *error = nil;
        [GBAROM unzipROMAtPathToROMDirectory:filepath withPreferredROMTitle:nil error:&error];
        
        if (error && [error code] == NSFileWriteFileExistsError)
        {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File Already Exists", @"")
                                                            message:NSLocalizedString(@"Please rename the existing file and try again.", @"")
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"") otherButtonTitles:nil];
            [alert show];
            
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
    }
    else
    {
        NSString *filename = [filepath lastPathComponent];
        
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
        
        BOOL fileExists = NO;
        
        for (NSString *item in contents)
        {
            if ([[[item pathExtension] lowercaseString] isEqualToString:@"gba"] || [[[item pathExtension] lowercaseString] isEqualToString:@"gbc"] ||
                [[[item pathExtension] lowercaseString] isEqualToString:@"gb"] || [[[item pathExtension] lowercaseString] isEqualToString:@"zip"])
            {
                NSString *name = [item stringByDeletingPathExtension];
                NSString *newFilename = [filename stringByDeletingPathExtension];
                
                if ([name isEqualToString:newFilename])
                {
                    fileExists = YES;
                    break;
                }
            }
        }
        
        if (fileExists)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File Already Exists", @"")
                                                            message:NSLocalizedString(@"Please rename either the existing file or the file to be imported and try again.", @"")
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Dismiss", @"") otherButtonTitles:nil];
            [alert show];
            
            [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        }
        else
        {
            [[NSFileManager defaultManager] moveItemAtPath:filepath toPath:[documentsDirectory stringByAppendingPathComponent:filename] error:nil];
        }
    }
}

- (void)copySkinAtPathToDocumentsDirectory:(NSString *)filepath
{
    [GBAController extractSkinAtPathToSkinsDirectory:filepath];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
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
