//
//  GBAAppDelegate.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//
//  Completed 2.0 2/19/14 3:46am CST.

#import "GBAAppDelegate.h"
#import "GBAEmulationViewController.h"
#import "GBASettingsViewController.h"
#import "GBAControllerSkin.h"
#import "GBAROM.h"
#import "GBASplitViewController.h"
#import "GBASoftwareUpdateOperation.h"
#import "GBASoftwareUpdateViewController.h"
#import "GBAEventDistributionOperation.h"
#import "GBALinkManager.h"
#import "GBASyncManager.h"

#import "SSZipArchive.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>

#import "UIView+DTDebug.h"
#import "NSDate+Comparing.h"
#import "UIAlertView+RSTAdditions.h"

#if !(TARGET_IPHONE_SIMULATOR)
#import <CrashReporter/CrashReporter.h>
#import <Crashlytics/Crashlytics.h>
#endif

NSString * const GBAUserRequestedToPlayROMNotification = @"GBAUserRequestedToPlayROMNotification";

static NSString * const GBALocalNotificationTypeKey = @"type";
static NSString * const GBALocalNotificationTypeSoftwareUpdate = @"softwareUpdate";
static NSString * const GBALocalNotificationTypeEventDistribution = @"eventDistribution";

static NSString * const GBALocalNotificationSoftwareUpdateKey = @"softwareUpdate";

static NSString * const GBACachedSoftwareUpdateKey = @"cachedSoftwareUpdate";
static NSString * const GBACachedEventDistributionsKey = @"cachedEventDistributions";
static NSString * const GBAAppVersionKey = @"appVersion";
static NSString * const GBALastCheckForUpdatesKey = @"lastCheckForUpdates";

static void * GBAApplicationCrashedContext = &GBAApplicationCrashedContext;

static GBAAppDelegate *_appDelegate;

@interface GBAAppDelegate ()

@property (strong, nonatomic) GBAEmulationViewController *emulationViewController;
@property (strong, nonatomic) UIViewController *presentedViewController;

@end

@implementation GBAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _appDelegate = self;
    
    //[UIView toggleViewMainThreadChecking];
    NSLog(@"%@",[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject]);
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"showedWarningAlert"])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Welcome to GBA4iOS!", @"")
                                                            message:NSLocalizedString(@"If at any time the app fails to open, please set the date back on your device at least 24 hours, then try opening the app again. Once the app is opened, you can set the date back to the correct time, and the app will continue to open normally. However, you'll need to repeat this process every time you restart your device.", @"")
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
        
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"showedWarningAlert"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    [DBClientsManager setupWithAppKey:@"obzx8requbc5bn5"];  // Setup Dropbox
    
    if (![[[NSUserDefaults standardUserDefaults] stringForKey:GBASyncDropboxAPIVersionKey] isEqualToString:@"2"]) {
        [GBASyncManager clearDropboxV1Data];
        [[NSUserDefaults standardUserDefaults] setObject:@"2" forKey:GBASyncDropboxAPIVersionKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
        
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.tintColor = GBA4iOS_PURPLE_COLOR;
    
    [[UISwitch appearance] setOnTintColor:GBA4iOS_PURPLE_COLOR]; // Apparently UISwitches don't inherit tint color from superview
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        self.emulationViewController = [[GBAEmulationViewController alloc] init];
        
        self.window.rootViewController = self.emulationViewController;
    }
    else
    {
        GBASplitViewController *splitViewController = [GBASplitViewController appropriateSplitViewController];
        self.window.rootViewController = splitViewController;
        
        self.emulationViewController = splitViewController.emulationViewController;
    }
    
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    [self preparePushNotifications];
    
    [GBASettingsViewController registerDefaults];
    
#ifndef USE_BLUETOOTH
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsLinkEnabled])
    {
        [[GBALinkManager sharedManager] start];
    }
    
#endif
    
#if !(TARGET_IPHONE_SIMULATOR)
    
//#warning Uncomment for release, and comment out Crashlytics. Can't have both at once :(
    //[self setUpCrashCallbacks];
    
    NSString *apiKey = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Crashlytics" ofType:@"apikey"] encoding:NSUTF8StringEncoding error:nil];
    
    if (apiKey.length)
    {
        [Crashlytics startWithAPIKey:apiKey];
    }
#endif
    
    [self.window makeKeyAndVisible];
    
    [self.emulationViewController showSplashScreen];
    
    return YES;
}

-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([url isFileURL])
    {
        [self handleFileURL:url];
    }
    else
    {
        return [self handleURLSchemeURL:url];
    }
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if ([url isFileURL])
    {
        [self handleFileURL:url];
    }
    else
    {
        return [self handleURLSchemeURL:url];
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

- (BOOL)handleURLSchemeURL:(NSURL *)url
{
    if ([[url scheme] hasPrefix:@"db"])
    {
        BOOL successful = NO;
        
        DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:url];
        if (authResult)
        {
            successful = [authResult isSuccess];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:GBASettingsDropboxStatusChangedNotification object:self userInfo:nil];
        
        return successful;
    }
    
    if ([[[url scheme] lowercaseString] isEqual:@"gba4ios"])
    {
        NSString *name = [[url host] stringByRemovingPercentEncoding];
        
        GBAROM *rom = [GBAROM romWithName:name];
        
        if (rom)
        {
            // Next run loop
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:GBAUserRequestedToPlayROMNotification object:rom userInfo:nil];
            });
            return YES;
        }
        
        rom = [GBAROM romWithUniqueName:name];
        
        if (rom)
        {
            // Next run loop
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:GBAUserRequestedToPlayROMNotification object:rom userInfo:nil];
            });
            return YES;
        }
        
        return NO;
    }
    
    return YES;
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
    [GBAControllerSkin extractSkinAtPathToSkinsDirectory:filepath];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
}

#pragma mark - Application Crashes

void applicationDidCrash(siginfo_t *info, ucontext_t *uap, void *context)
{
    [_appDelegate.emulationViewController autoSaveIfPossible];
}

- (void)setUpCrashCallbacks
{
    
#if !(TARGET_IPHONE_SIMULATOR)
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    
    // Not interested in actual crashes; we use Crashlytics for that.
    [crashReporter purgePendingCrashReport];
    
    PLCrashReporterCallbacks callbacks = {
        .version = 0,
        .context = GBAApplicationCrashedContext,
        .handleSignal = applicationDidCrash
    };
    
    [crashReporter setCrashCallbacks:&callbacks];
    
    NSError *error = nil;
    
    if (![crashReporter enableCrashReporterAndReturnError: &error])
    {
        DLog(@"Error loading crash reporter: %@", error);
    }
    
#endif
}

#pragma mark - Push Notifications

- (void)preparePushNotifications
{
    // Uncomment to removed cached events and update information
    //[[NSUserDefaults standardUserDefaults] removeObjectForKey:GBACachedSoftwareUpdateKey];
    //[[NSUserDefaults standardUserDefaults] removeObjectForKey:GBACachedEventDistributionsKey];
    //[[NSUserDefaults standardUserDefaults] synchronize];
    
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:1 * 60 * 60 * 12]; // Check approximately twice a day (keep the app alive without iOS preving opening due to expired certificate)
    
    if ([UIUserNotificationSettings class])
    {
        UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    }
    
    // Delay until after app boots up
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *previousAppVersion = [[NSUserDefaults standardUserDefaults] objectForKey:GBAAppVersionKey];
        NSString *currentAppVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        
        // No previous version, or current app version is newer than previous
        if (!previousAppVersion || [previousAppVersion compare:currentAppVersion options:NSNumericSearch] == NSOrderedAscending)
        {
            [[NSUserDefaults standardUserDefaults] setObject:currentAppVersion forKey:GBAAppVersionKey];
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        }
        
        // Manually check for updates
        NSDate *lastManualFetch = [[NSUserDefaults standardUserDefaults] objectForKey:GBALastCheckForUpdatesKey];
        NSInteger daysPassed = [[NSDate date] daysSinceDate:lastManualFetch];
        
        if (!lastManualFetch || daysPassed > 0)
        {
            [self manuallyCheckForUpdates];
        }
        
    });
    
}

- (void)manuallyCheckForUpdates
{
    [self performChecksForSoftwareUpdatesWithCompletion:^(GBASoftwareUpdate *softwareUpdate) {
        // Software Update Available
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSString *updateMessage = [NSString stringWithFormat:@"%@ %@", softwareUpdate.name, NSLocalizedString(@"is now available for download.", @"")];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Software Update Available", @"")
                                                            message:updateMessage
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Later", @"")
                                                  otherButtonTitles:NSLocalizedString(@"Update", @""), nil];
            
            [alert showWithSelectionHandler:^(UIAlertView *alertView, NSInteger buttonIndex) {
                
                if (buttonIndex == 1)
                {
                    [self presentSoftwareUpdateViewControllerWithSoftwareUpdate:softwareUpdate];
                }
                
            }];
            
        });
        
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
        
        
    } andEventsWithCompletion:^(GBAEvent *event) {
        // New Event Available
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSString *message = nil;
            NSString *localizedSupportedGames = event.localizedSupportedGames;
            
            if (localizedSupportedGames)
            {
                message = [NSString stringWithFormat:NSLocalizedString(@"The event “%@” is now available for download for %@.", @"Leave the %@'s, they are placeholders for the event name and Pokemon games"), event.name, localizedSupportedGames];
            }
            else
            {
                message = [NSString stringWithFormat:NSLocalizedString(@"The event “%@” is now available for download.", @"Leave the %@'s, they are placeholders for the event name"), event.name];
            }
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"New Event Available", @"")
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"OK", @""), nil];
            
            [alert show];
            
        });
        
    } backgroundFetchCompletionHandler:nil];
    
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:GBALastCheckForUpdatesKey];
}

- (void)presentSoftwareUpdateViewControllerWithSoftwareUpdate:(GBASoftwareUpdate *)softwareUpdate
{
    if (self.presentedViewController)
    {
        return;
    }
    
    GBASoftwareUpdateViewController *softwareUpdateViewController = [[GBASoftwareUpdateViewController alloc] initWithSoftwareUpdate:softwareUpdate];
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissPresentedViewController:)];
    softwareUpdateViewController.navigationItem.leftBarButtonItem = cancelButton;
    
    self.presentedViewController = softwareUpdateViewController;
    [self.emulationViewController prepareAndPresentViewController:softwareUpdateViewController];
}

- (void)dismissPresentedViewController:(UIBarButtonItem *)barButtonItem
{
    [self.emulationViewController prepareForDismissingPresentedViewController:self.presentedViewController];
    [self.presentedViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    
    self.presentedViewController = nil;
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if ([UIUserNotificationSettings class])
    {
        UIUserNotificationSettings *currentSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        
        if (currentSettings.types == UIUserNotificationTypeNone)
        {
            return;
        }
    }
    
    [self performChecksForSoftwareUpdatesWithCompletion:^(GBASoftwareUpdate *softwareUpdate) {
        // Software Update Available
        
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.applicationIconBadgeNumber = 1;
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        localNotification.alertAction = NSLocalizedString(@"View", @"");
        localNotification.userInfo = @{GBALocalNotificationTypeKey: GBALocalNotificationTypeSoftwareUpdate, GBALocalNotificationSoftwareUpdateKey: [softwareUpdate dataRepresentation]};
        
        NSString *updateMessage = [NSString stringWithFormat:@"%@ %@", softwareUpdate.name, NSLocalizedString(@"is now available for download.", @"")];
        localNotification.alertBody = updateMessage;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
        
    } andEventsWithCompletion:^(GBAEvent *event) {
        // New Event Available
        
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        localNotification.alertAction = NSLocalizedString(@"View", @"");
        localNotification.userInfo = @{GBALocalNotificationTypeKey: GBALocalNotificationTypeEventDistribution};
        
        NSString *updateMessage = nil;
        NSString *localizedSupportedGames = event.localizedSupportedGames;
        
        if (localizedSupportedGames)
        {
            updateMessage = [NSString stringWithFormat:NSLocalizedString(@"The event “%@” is now available for download for %@.", @"Leave the %@'s, they are placeholders for the event name and Pokemon games"), event.name, localizedSupportedGames];
        }
        else
        {
            updateMessage = [NSString stringWithFormat:NSLocalizedString(@"The event “%@” is now available for download.", @"Leave the %@'s, they are placeholders for the event name"), event.name];
        }
        
        localNotification.alertBody = updateMessage;
        
        [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
        
    } backgroundFetchCompletionHandler:completionHandler];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    if (application.applicationState == UIApplicationStateActive)
    {
        return;
    }
    
    if ([notification.userInfo[GBALocalNotificationTypeKey] isEqualToString:GBALocalNotificationTypeSoftwareUpdate])
    {
        NSData *softwareUpdateData = notification.userInfo[GBALocalNotificationSoftwareUpdateKey];
        GBASoftwareUpdate *softwareUpdate = [[GBASoftwareUpdate alloc] initWithData:softwareUpdateData];
        [self presentSoftwareUpdateViewControllerWithSoftwareUpdate:softwareUpdate];
    }
}

- (void)performChecksForSoftwareUpdatesWithCompletion:(void (^)(GBASoftwareUpdate *))softwareUpdateCompletionBlock
                              andEventsWithCompletion:(void (^)(GBAEvent *))eventDistributionCompletionBlock
                     backgroundFetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    GBASoftwareUpdateOperation *softwareUpdateOperation = [GBASoftwareUpdateOperation new];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsSoftwareUpdatePushNotificationsKey] && completionHandler)
    {
        DLog(@"Software Update Push Notifications Disabled");
        [softwareUpdateOperation setPerformsNoOperation:YES];
    }
    
    [softwareUpdateOperation checkForUpdateWithCompletion:^(GBASoftwareUpdate *softwareUpdate, NSError *error) {
        
        // Don't return if softwareUpdate is nil, in case we perform no network operation
        
        if (error)
        {
            ELog(error);
            
            if (completionHandler)
            {
                completionHandler(UIBackgroundFetchResultFailed);
            }
            
            return;
        }
        
        NSString *cachedSoftwareUpdateVersion = [[NSUserDefaults standardUserDefaults] objectForKey:GBACachedSoftwareUpdateKey];
        
        __block UIBackgroundFetchResult backgroundFetchResult = UIBackgroundFetchResultNoData;
        
        if (![cachedSoftwareUpdateVersion isEqualToString:softwareUpdate.version] && [softwareUpdate isNewerThanAppVersion] && [softwareUpdate isSupportedOnCurrentiOSVersion])
        {
            if (softwareUpdateCompletionBlock)
            {
                softwareUpdateCompletionBlock(softwareUpdate);
            }
            
            [[NSUserDefaults standardUserDefaults] setObject:softwareUpdate.version forKey:GBACachedSoftwareUpdateKey];
            
            backgroundFetchResult = UIBackgroundFetchResultNewData;
        }
        else
        {
            DLog(@"Software update is not new");
        }
        
        
        GBAEventDistributionOperation *eventDistributionOperation = [GBAEventDistributionOperation new];
        
        if (![[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsEventDistributionPushNotificationsKey] && completionHandler)
        {
            DLog(@"Event Distribution Push Notifications Disabled");
            [eventDistributionOperation setPerformsNoOperation:YES];
        }
        
        [eventDistributionOperation checkForEventsWithCompletion:^(NSArray *events, NSError *error) {
            
            // Don't return if events is nil, in case we perform no network operation
            
            if (error)
            {
                ELog(error);
                
                if (completionHandler)
                {
                    completionHandler(UIBackgroundFetchResultFailed);
                }
                
                return;
            }
            
            NSMutableArray *cachedEvents = [[[NSUserDefaults standardUserDefaults] objectForKey:GBACachedEventDistributionsKey] mutableCopy];
            
            if (cachedEvents == nil)
            {
                cachedEvents = [NSMutableArray array];
            }
            
            __block GBAEvent *event = nil;
            
            [events enumerateObjectsUsingBlock:^(GBAEvent *potentialEvent, NSUInteger index, BOOL *stop) {
                
                if ([potentialEvent isExpired])
                {
                    return;
                }
                
                if (![self userHasSupportedGameForEvent:potentialEvent])
                {
                    return;
                }
                
                if ([cachedEvents containsObject:potentialEvent.identifier])
                {
                    return;
                }
                    
                event = potentialEvent;
                
            }];
            
            if (event)
            {
                if (eventDistributionCompletionBlock)
                {
                    eventDistributionCompletionBlock(event);
                }
                
                [cachedEvents addObject:event.identifier];
                
                [[NSUserDefaults standardUserDefaults] setObject:cachedEvents forKey:GBACachedEventDistributionsKey];
                
                backgroundFetchResult = UIBackgroundFetchResultNewData;
            }
            else
            {
                DLog(@"No new events");
            }
            
            if (completionHandler)
            {
                completionHandler(backgroundFetchResult);
            }
            
        }];
        
        
    }];
}

- (NSString *)cachedROMsPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    return [libraryDirectory stringByAppendingPathComponent:@"cachedROMs.plist"];
}

- (BOOL)userHasSupportedGameForEvent:(GBAEvent *)event
{
    // Determine if user has any of the event's supported games installed
    NSString *path = [[NSBundle mainBundle] pathForResource:@"eventDistributionROMs" ofType:@"plist"];
    NSDictionary *compatibleROMsDictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    NSSet *compatibleROMs = [NSSet setWithArray:compatibleROMsDictionary.allKeys];
    
    NSDictionary *cachedROMsDictionary = [NSDictionary dictionaryWithContentsOfFile:[self cachedROMsPath]];
    NSMutableSet *cachedROMs = [NSMutableSet setWithArray:cachedROMsDictionary.allValues];
    
    [cachedROMs intersectSet:compatibleROMs];
    
    __block BOOL userHasSupportedGame = NO;
    
    [cachedROMs enumerateObjectsUsingBlock:^(NSString *uniqueName, BOOL *stop) {
        
        if (([uniqueName hasPrefix:@"POKEMON RUBY"] && [event supportsGame:GBAEventSupportedGameRuby]) ||
            ([uniqueName hasPrefix:@"POKEMON SAPP"] && [event supportsGame:GBAEventSupportedGameSapphire]) ||
            ([uniqueName hasPrefix:@"POKEMON FIRE"] && [event supportsGame:GBAEventSupportedGameFireRed]) ||
            ([uniqueName hasPrefix:@"POKEMON LEAF"] && [event supportsGame:GBAEventSupportedGameLeafGreen]) ||
            ([uniqueName hasPrefix:@"POKEMON EMER"] && [event supportsGame:GBAEventSupportedGameEmerald]))
        {
            userHasSupportedGame = YES;
            *stop = YES;
        }
        
    }];
    
    return userHasSupportedGame;
}

#pragma mark - UIApplicationDelegate

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
