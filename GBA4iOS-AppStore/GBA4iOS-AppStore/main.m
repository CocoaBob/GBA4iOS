//
//  main.m
//  GBA4iOS-AppStore
//
//  Created by Riley Testut on 8/16/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <dlfcn.h>

#import "GBAAppStoreAppDelegate.h"
#import "libGBA4iOS.h"

int main(int argc, char * argv[])
{
    @autoreleasepool
    {
        
        NSString *dylibPath = [[NSBundle mainBundle] pathForResource:@"libGBA4iOS" ofType:@"dylib"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:dylibPath])
        {
            void *libGBA4iOS = dlopen([dylibPath cStringUsingEncoding:NSUTF8StringEncoding], RTLD_NOW);
            
            if (libGBA4iOS)
            {
                [NSClassFromString(@"libGBA4iOS") startWithArgument1:argc argument2:argv];
            }
            else
            {
                char *error = dlerror();
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error Loading GBA4iOS", @"") message:[NSString stringWithFormat:@"%s", error] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                });
            }
        }
        
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([GBAAppStoreAppDelegate class]));
    }
}
