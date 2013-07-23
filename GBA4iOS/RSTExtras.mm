#define thisModuleName "base:iphone"

#import "MainApp.h"
#import "EAGLView.h"
#import <dlfcn.h>
#import <unistd.h>

#include <base/common/funcs.h>

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <Foundation/NSPathUtilities.h>

#import "EAGLView_Private.h"

#ifdef CONFIG_INPUT_ICADE
#include "ICadeHelper.hh"
#endif

#import "SharedNamespace.hh"

#import "ImagineUIViewController.h"

#ifdef CONFIG_INPUT_ICADE

namespace Input
{
    
    void Device::setICadeMode(bool on)
    {
        if(map_ == Input::Event::MAP_ICADE) // BT Keyboard always treated as iCade
        {
            logMsg("set iCade mode %s for %s", on ? "on" : "off", name());
            iCadeMode_ = on;
            Base::iCade.setActive(on);
        }
        else if(on)
            logWarn("tried to set iCade mode on device with map %d", map_);
    }
    
}

#endif

