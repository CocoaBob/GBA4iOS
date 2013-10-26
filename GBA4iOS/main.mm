//
//  main.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAAppDelegate.h"

int app_argc = 0;
char **app_argv;

int main(int argc, char * argv[])
{
    app_argc = argc;
    app_argv = argv;
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([GBAAppDelegate class]));
    }
}