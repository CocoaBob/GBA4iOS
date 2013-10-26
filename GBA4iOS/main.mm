//
//  main.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/18/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GBAAppDelegate.h"

#if !(TARGET_IPHONE_SIMULATOR)

#include <fs/sys.hh>

// Emulator Includes
#include <util/time/sys.hh>
#include <base/Base.hh>
#include <base/iphone/private.hh>

#ifdef CONFIG_INPUT
#include <input/Input.hh>
#endif

typedef int (*PYStdWriter)(void *, const char *, int);
static PYStdWriter _oldStdWrite;

int __pyStderrWrite(void *inFD, const char *buffer, int size)
{
    if ( strncmp(buffer, "AssertMacros:", 13) == 0 ) {
        return 0;
    }
    return _oldStdWrite(inFD, buffer, size);
}


double TimeMach::timebaseNSec = 0, TimeMach::timebaseUSec = 0,
TimeMach::timebaseMSec = 0, TimeMach::timebaseSec = 0;

int main(int argc, char * argv[])
{
    
    _oldStdWrite = stderr->_write;
    stderr->_write = __pyStderrWrite;
    
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
    
#warning REMEMBER TO CHANGE THIS
    doOrExit(Base::onInit_GBC(argc, argv));
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([GBAAppDelegate class]));
    }
}

#else

int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([GBAAppDelegate class]));
    }
}

#endif
