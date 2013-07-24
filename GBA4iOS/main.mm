//
//  main.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAAppDelegate.h"




#include <fs/sys.hh>

// Emulator Includes
#include <util/time/sys.hh>
#include <base/Base.hh>
#include <base/iphone/private.hh>

#ifdef CONFIG_INPUT
#include <input/Input.hh>
#endif

double TimeMach::timebaseNSec = 0, TimeMach::timebaseUSec = 0,
TimeMach::timebaseMSec = 0, TimeMach::timebaseSec = 0;

int main(int argc, char * argv[])
{
    
    doOrExit(logger_init());
	TimeMach::setTimebase();
    
#ifdef CONFIG_FS
	FsPosix::changeToAppDir(argv[0]);
#endif
    
#ifdef CONFIG_INPUT
	doOrExit(Input::init());
#endif
	
#ifdef CONFIG_AUDIO
	Audio::initSession();
#endif
    
    Base::grayColorSpace = CGColorSpaceCreateDeviceGray();
	Base::rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    doOrExit(Base::onInit(argc, argv));
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([GBAAppDelegate class]));
    }
}
