//
//  MainApp.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "MainApp.h"
#import "EAGLView.h"

#include <base/common/funcs.h>

#import "SharedNamespace.hh"
#import "ImagineUIViewController.h"
#import "EAGLView_Private.h"

@implementation MainApp

#if defined(CONFIG_INPUT) && defined(IPHONE_VKEYBOARD)
/*- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
 {
 if (textView.text.length >= 127 && range.length == 0)
 {
 logMsg("not changing text");
 return NO;
 }
 return YES;
 }
 
 - (void)textViewDidEndEditing:(UITextView *)textView
 {
 logMsg("editing ended");
 Input::finishSysTextInput();
 }*/

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	logMsg("pushed return");
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	using namespace Input;
	logMsg("editing ended");
	//inVKeyboard = 0;
	auto delegate = vKeyboardTextDelegate;
	vKeyboardTextDelegate = {};
	char text[256];
	string_copy(text, [textField.text UTF8String]);
	[textField removeFromSuperview];
	vkbdField = nil;
	if(delegate)
	{
		logMsg("running text entry callback");
		delegate(text);
	}
}

#endif

#if 0
- (void)keyboardWasShown:(NSNotification *)notification
{
	return;
	using namespace Base;
#ifndef NDEBUG
	CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
	logMsg("keyboard shown with size %d", (int)keyboardSize.height * pointScale);
	int visibleY = IG::max(1, int(mainWin.rect.y2 - keyboardSize.height * pointScale));
	float visibleFraction = visibleY / mainWin.rect.y2;
	/*if(isIPad)
     Gfx::viewMMHeight_ = 197. * visibleFraction;
     else
     Gfx::viewMMHeight_ = 75. * visibleFraction;*/
	//generic_resizeEvent(mainWin.rect.x2, visibleY);
#endif
	displayNeedsUpdate();
}

- (void) keyboardWillHide:(NSNotification *)notification
{
	return;
	using namespace Base;
	logMsg("keyboard hidden");
	displayNeedsUpdate();
}
#endif

/*- (void) screenDidConnect:(NSNotification *)aNotification
 {
 logMsg("New screen connected");
 UIScreen *screen = [aNotification object];
 UIScreenMode *mode = [[screen availibleModes] lastObject];
 screen.currentMode = mode;
 if(!externalWindow)
 {
 externalWindow = [UIWindow alloc];
 }
 CGRect rect = CGRectMake(0, 0, mode.size.width, mode.size.height);
 [externalWindow initWithFrame:rect];
 externalWindow.screen = screen;
 [externalWindow makeKeyAndVisible];
 }
 
 - (void) screenDidDisconnect:(NSNotification *)aNotification
 {
 logMsg("Screen dis-connected");
 }
 
 - (void) screenModeDidChange:(NSNotification *)aNotification
 {
 UIScreen *screen = [aNotification object];
 logMsg("Screen-mode change"); // [screen currentMode]
 }*/

static uint iOSOrientationToGfx(UIDeviceOrientation orientation)
{
	switch(orientation)
	{
		case UIDeviceOrientationPortrait: return Gfx::VIEW_ROTATE_0;
		case UIDeviceOrientationLandscapeLeft: return Gfx::VIEW_ROTATE_90;
		case UIDeviceOrientationLandscapeRight: return Gfx::VIEW_ROTATE_270;
		case UIDeviceOrientationPortraitUpsideDown: return Gfx::VIEW_ROTATE_180;
		default : return 255; // TODO: handle Face-up/down
	}
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	using namespace Base;
	NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
#ifndef NDEBUG
	//logMsg("in didFinishLaunchingWithOptions(), UUID %s", [[[UIDevice currentDevice] uniqueIdentifier] cStringUsingEncoding: NSASCIIStringEncoding]);
	logMsg("iOS version %s", [currSysVer cStringUsingEncoding: NSASCIIStringEncoding]);
#endif
	mainApp = self;
	
	// unused for now since ARMv7 build now requires 4.3
	/*NSString *reqSysVer = @"4.0";
     if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
     {
     //logMsg("enabling iOS 4 features");
     usingiOS4 = 1;
     }*/
	
	/*if ([currSysVer compare:@"3.2" options:NSNumericSearch] != NSOrderedAscending)
     {
     logMsg("enabling iOS 3.2 external display features");
     NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
     [center addObserver:self selector:@selector(screenDidConnect:) name:UIScreenDidConnectNotification object:nil];
     [center addObserver:self selector:@selector(screenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
     [center addObserver:self selector:@selector(screenModeDidChange:) name:UIScreenModeDidChangeNotification object:nil];
     }*/
	
	// TODO: get real DPI if possible
	// based on iPhone/iPod DPI of 163 (326 retina)
	uint unscaledDPI = 163;
#if !defined(__ARM_ARCH_6K__) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= 30200)
	if(isIPad)
	{
		// based on iPad DPI of 132 (264 retina)
		unscaledDPI = 132;
		
		/*rotateView = preferedOrientation = iOSOrientationToGfx([[UIDevice currentDevice] orientation]);
         logMsg("started in %s orientation", Gfx::orientationName(rotateView));
         #ifdef CONFIG_INPUT
         Gfx::configureInputForOrientation();
         #endif*/
	}
#endif
    
	CGRect rect = [[UIScreen mainScreen] bounds];
	mainWin.w = mainWin.rect.x2 = rect.size.width;
	mainWin.h = mainWin.rect.y2 = rect.size.height;
	Gfx::viewMMWidth_ = std::round((mainWin.w / (float)unscaledDPI) * 25.4);
	Gfx::viewMMHeight_ = std::round((mainWin.h / (float)unscaledDPI) * 25.4);
	logMsg("set screen MM size %dx%d", Gfx::viewMMWidth_, Gfx::viewMMHeight_);
	currWin = mainWin;
	// Create a full-screen window
	devWindow = [[UIWindow alloc] initWithFrame:rect];
	
#ifdef GREYSTRIPE
	initGS(self);
#endif
	
	NSNotificationCenter *nCenter = [NSNotificationCenter defaultCenter];
	[nCenter addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
	//[nCenter addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
	//[nCenter addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	
	// Create the OpenGL ES view and add it to the Window
	glView = [[EAGLView alloc] initWithFrame:rect];
#ifdef CONFIG_INPUT_ICADE
	iCade.init(glView);
#endif
	Base::engineInit();
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
	Base::setAutoOrientation(1);
    
	// view controller init
	if(usingiOS4)
	{
		viewCtrl = [[ImagineUIViewController alloc] init];
		viewCtrl.view = glView;
		devWindow.rootViewController = viewCtrl;
	}
	else
	{
		[devWindow addSubview:glView];
	}
    
	[devWindow makeKeyAndVisible];
	logMsg("exiting didFinishLaunchingWithOptions");
	return YES;
}

- (void)orientationChanged:(NSNotification *)notification
{
	uint o = iOSOrientationToGfx([[UIDevice currentDevice] orientation]);
	if(o == 255)
		return;
	if(o == Gfx::VIEW_ROTATE_180 && !Base::isIPad)
		return; // ignore upside-down orientation unless using iPad
	logMsg("new orientation %s", Gfx::orientationName(o));
	Gfx::preferedOrientation = o;
	Gfx::setOrientation(Gfx::preferedOrientation);
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	logMsg("resign active");
	Base::stopAnimation();
	glFinish();
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	using namespace Base;
	logMsg("became active");
	if(!Base::openglViewIsInit)
		[glView createFramebuffer];
	Base::appState = APP_RUNNING;
	if(Base::displayLink)
		Base::startAnimation();
	Base::onResume(1);
#ifdef CONFIG_INPUT_ICADE
	iCade.didBecomeActive();
#endif
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	using namespace Base;
	logMsg("app exiting");
	//Base::stopAnimation();
	Base::appState = APP_EXITING;
	Base::onExit(0);
	logMsg("app exited");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	using namespace Base;
	logMsg("entering background");
	appState = APP_PAUSED;
	Base::stopAnimation();
	Base::onExit(1);
#ifdef CONFIG_INPUT_ICADE
	iCade.didEnterBackground();
#endif
	glFinish();
	[glView destroyFramebuffer];
	logMsg("entered background");
}

- (void)timerCallback:(id)callback
{
	using namespace Base;
	logMsg("running callback");
	NSData *callbackData = (NSData*)callback;
	CallbackDelegate del;
	[callbackData getBytes:&del length:sizeof(del)];
	del();
}

- (void)handleThreadMessage:(NSValue *)arg
{
	using namespace Base;
	ThreadMsg msg;
	[arg getValue:&msg];
	processAppMsg(msg.type, msg.shortArg, msg.intArg, msg.intArg2);
}

- (void)dealloc
{
	//[glView release]; // retained in devWindow
}

@end
