//
//  SharedNamespace.h
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#ifndef GBA4iOS_SharedNamespace_h
#define GBA4iOS_SharedNamespace_h

@interface NSObject (GBAWarningSilencer)

- (void)timerCallback:(NSTimer *)timer;
- (void)handleThreadMessage:(NSValue *)value;

@end

namespace Base
{
	static UIWindow *devWindow;
	static int pointScale = 1;
	static NSObject *mainApp;
}

static CGAffineTransform makeTransformForOrientation(uint orientation)
{
	using namespace Gfx;
	switch(orientation)
	{
		default: return CGAffineTransformIdentity;
		case VIEW_ROTATE_270: return CGAffineTransformMakeRotation(3*M_PI / 2.0);
		case VIEW_ROTATE_90: return CGAffineTransformMakeRotation(M_PI / 2.0);
		case VIEW_ROTATE_180: return CGAffineTransformMakeRotation(M_PI);
	}
}

#if defined(CONFIG_INPUT) && defined(IPHONE_VKEYBOARD)

namespace Input
{
	//static UITextView *vkbdField = nil;
	static UITextField *vkbdField = nil;
	//static bool inVKeyboard = 0;
	static InputTextDelegate vKeyboardTextDelegate;
	static Rect2<int> textRect(8, 200, 8+304, 200+48);
}
#endif

#ifdef CONFIG_INPUT
#include "input.h"
#endif

namespace Base
{
    
    struct ThreadMsg
    {
        int16 type;
        int16 shortArg;
        int intArg;
        int intArg2;
    };
    
    const char *appPath = 0;
    static UIWindow *externalWindow = 0;
    static EAGLView *glView;
    static EAGLContext *mainContext = nullptr;
    static CADisplayLink *displayLink = 0;
    static BOOL displayLinkActive = NO;
    static bool isIPad = 0;
    static bool useMaxColorBits = Config::MACHINE_IS_GENERIC_ARMV7;
#ifdef __ARM_ARCH_6K__
    static bool usingiOS4 = 0;
#else
    static const bool usingiOS4 = 1; // always on iOS 4.3+ when compiled for ARMv7
#endif
    ;
#ifdef CONFIG_INPUT_ICADE
    static ICadeHelper iCade = { nil };
#endif
    CGColorSpaceRef grayColorSpace = nullptr, rgbColorSpace = nullptr;
    
    // used on iOS 4.0+
    static UIViewController *viewCtrl;
    
#ifdef IPHONE_IMG_PICKER
	static UIImagePickerController* imagePickerController;
	static IPhoneImgPickerCallback imgPickCallback = NULL;
	static void *imgPickUserPtr = NULL;
	static NSData *imgPickData[2];
	static uchar imgPickDataElements = 0;
#include "imagePicker.h"
#endif
    
#ifdef IPHONE_MSG_COMPOSE
	static MFMailComposeViewController *composeController;
#include "mailCompose.h"
#endif
    
#ifdef IPHONE_GAMEKIT
#include "gameKit.h"
#endif
    
#ifdef GREYSTRIPE
#include "greystripe.h"
#endif
    
    static const int USE_DEPTH_BUFFER = 0;
    static int openglViewIsInit = 0;
    
    void cancelCallback(CallbackRef *ref)
    {
        if(ref)
        {
            logMsg("cancelling callback with ref %p", ref);
            [NSObject cancelPreviousPerformRequestsWithTarget:mainApp selector:@selector(timerCallback:) object:CFBridgingRelease(ref)];
        }
    }
    
    CallbackRef *callbackAfterDelay(CallbackDelegate callback, int ms)
    {
        logMsg("setting callback to run in %d ms", ms);
        CallbackDelegate del(callback);
        NSData *callbackArg = [[NSData alloc] initWithBytes:&del length:sizeof(del)];
        assert(callbackArg);
        [mainApp performSelector:@selector(timerCallback:) withObject:(id)callbackArg afterDelay:(float)ms/1000.];
        
//#warning Check memory usage Riley Testut
        
        return (CallbackRef*)CFBridgingRetain(callbackArg);
    }
    
    void openGLUpdateScreen()
    {
        //logMsg("doing swap");
        //glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
        [Base::mainContext presentRenderbuffer:GL_RENDERBUFFER_OES];
    }
    
    void startAnimation()
    {
        if(!Base::displayLinkActive)
        {
            displayLink.paused = NO;
            Base::displayLinkActive = YES;
        }
    }
    
    void stopAnimation()
    {
        if(Base::displayLinkActive)
        {
            displayLink.paused = YES;
            Base::displayLinkActive = NO;
        }
    }
    
    uint appState = APP_RUNNING;
    
}

namespace Base
{
    
    void nsLog(const char* str)
    {
        NSLog(@"%s", str);
    }
    
    void nsLogv(const char* format, va_list arg)
    {
        auto formatStr = [[NSString alloc] initWithBytesNoCopy:(void*)format length:strlen(format) encoding:NSUTF8StringEncoding freeWhenDone:false];
        NSLogv(formatStr, arg);
    }
    
    void setVideoInterval(uint interval)
    {
        logMsg("setting frame interval %d", (int)interval);
        assert(interval >= 1);
        [Base::displayLink setFrameInterval:interval];
    }
    
    static void setViewportForStatusbar(UIApplication *sharedApp)
    {
        using namespace Gfx;
        mainWin.rect.x = mainWin.rect.y = 0;
        mainWin.rect.x2 = mainWin.w;
        mainWin.rect.y2 = mainWin.h;
        //logMsg("status bar hidden %d", sharedApp.statusBarHidden);
        /*if(!sharedApp.statusBarHidden)
        {
            bool isSideways = rotateView == VIEW_ROTATE_90 || rotateView == VIEW_ROTATE_270;
            auto statusBarHeight = (isSideways ? sharedApp.statusBarFrame.size.width : sharedApp.statusBarFrame.size.height) * pointScale;
            if(isSideways)
            {
                if(rotateView == VIEW_ROTATE_270)
                    mainWin.rect.x = statusBarHeight;
                else
                    mainWin.rect.x2 -= statusBarHeight;
            }
            else
            {
                mainWin.rect.y = statusBarHeight;
            }
            logMsg("status bar height %d", (int)statusBarHeight);
            logMsg("adjusted window to %d:%d:%d:%d", mainWin.rect.x, mainWin.rect.y, mainWin.rect.x2, mainWin.rect.y2);
        }*/
    }
    
    void setStatusBarHidden(uint hidden)
    {
        auto sharedApp = [UIApplication sharedApplication];
        assert(sharedApp);
/*#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 30200
		[sharedApp setStatusBarHidden: hidden ? YES : NO withAnimation: UIStatusBarAnimationFade];
#else
		[sharedApp setStatusBarHidden: hidden ? YES : NO animated:YES];
#endif Riley Testut */
        //Riley Testut setViewportForStatusbar(sharedApp);
        generic_resizeEvent(mainWin);
    }
    
    static UIInterfaceOrientation gfxOrientationToUIInterfaceOrientation(uint orientation)
    {
        using namespace Gfx;
        switch(orientation)
        {
            default: return UIInterfaceOrientationPortrait;
            case VIEW_ROTATE_270: return UIInterfaceOrientationLandscapeLeft;
            case VIEW_ROTATE_90: return UIInterfaceOrientationLandscapeRight;
            case VIEW_ROTATE_180: return UIInterfaceOrientationPortraitUpsideDown;
        }
    }
    
    void setSystemOrientation(uint o)
    {
        using namespace Input;
        if(vKeyboardTextDelegate) // TODO: allow orientation change without aborting text input
        {
            logMsg("aborting active text input");
            vKeyboardTextDelegate(nullptr);
            vKeyboardTextDelegate = {};
        }
        auto sharedApp = [UIApplication sharedApplication];
        assert(sharedApp);
        [sharedApp setStatusBarOrientation:gfxOrientationToUIInterfaceOrientation(o) animated:YES];
        setViewportForStatusbar(sharedApp);
    }
    
    static bool autoOrientationState = 0; // Turned on in applicationDidFinishLaunching
    
    void setAutoOrientation(bool on)
    {
        if(autoOrientationState == on)
            return;
        autoOrientationState = on;
        logMsg("set auto-orientation: %d", on);
        if(on)
            [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        else
        {
            Gfx::preferedOrientation = Gfx::rotateView;
            [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
        }
    }
    
    void exitVal(int returnVal)
    {
        appState = APP_EXITING;
        onExit(0);
        ::exit(returnVal);
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-noreturn"
    void abort() { }
#pragma clang diagnostic pop
    
    void displayNeedsUpdate()
    {
        generic_displayNeedsUpdate();
        if(appState == APP_RUNNING && Base::displayLinkActive == NO)
        {
            Base::startAnimation();
        }
    }
    
    void openURL(const char *url)
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:
                                                    [NSString stringWithCString:url encoding:NSASCIIStringEncoding]]];
    }
    
    void setIdleDisplayPowerSave(bool on)
    {
        auto sharedApp = [UIApplication sharedApplication];
        assert(sharedApp);
        sharedApp.idleTimerDisabled = on ? NO : YES;
        logMsg("set idleTimerDisabled %d", (int)sharedApp.idleTimerDisabled);
    }
    
    void sendMessageToMain(ThreadPThread &, int type, int shortArg, int intArg, int intArg2)
    {
        ThreadMsg msg = { (int16)type, (int16)shortArg, intArg, intArg2 };
        NSValue *arg = [[NSValue alloc] initWithBytes:&msg objCType:@encode(Base::ThreadMsg)];
        [mainApp performSelectorOnMainThread:@selector(handleThreadMessage:)
                                  withObject:arg
                               waitUntilDone:NO];
    }
    
    static const char *docPath = 0;
    
    const char *documentsPath()
    {
        if(!docPath)
        {
#ifdef CONFIG_BASE_IOS_JB
			return "/User/Library/Preferences";
#else
			NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
			NSString *documentsDirectory = [paths objectAtIndex:0];
			docPath = strdup([documentsDirectory cStringUsingEncoding: NSASCIIStringEncoding]);
#endif
        }
        return docPath;
    }
    
    const char *storagePath()
    {
#ifdef CONFIG_BASE_IOS_JB
		return "/User/Media";
#else
		return documentsPath();
#endif
    }
    
    bool deviceIsIPad()
    {
        return isIPad;
    }
    
#ifdef CONFIG_BASE_IOS_SETUID
    
    uid_t realUID = 0, effectiveUID = 0;
    static void setupUID()
    {
        realUID = getuid();
        effectiveUID = geteuid();
        seteuid(realUID);
    }
    
    void setUIDReal()
    {
        seteuid(Base::realUID);
    }
    
    bool setUIDEffective()
    {
        return seteuid(Base::effectiveUID) == 0;
    }
    
#endif
    
    bool supportsFrameTime()
    {
        return true;
    }
    
    void setWindowPixelBestColorHint(bool best)
    {
       // assert(!mainContext); // should only call before initial window is created Riley Testut
        useMaxColorBits = best;
    }
    
    bool windowPixelBestColorHintDefault()
    {
        return Config::MACHINE_IS_GENERIC_ARMV7;
    }
    
}

#endif
