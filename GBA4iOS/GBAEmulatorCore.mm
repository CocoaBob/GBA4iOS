//
//  GBAEmulatorCore.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <libkern/OSAtomic.h>

#import "GBAEmulatorCore.h"
#import "UIDevice-Hardware.h"
#import "GBAROM_Private.h"
#import "GBAEvent.h"

#import "MainApp.h"
#import "EAGLView.h"
#import "GBASettingsViewController.h"
#import "GBALinkManager.h"
#import "GBABluetoothLinkManager.h"

#import "EAGLView_Private.h"

#include <base/common/funcs.h>

#import "Namespace.h"

#import <EmuOptions.hh>
#import <VController.hh>
#import <EmuView.hh>
#import <gba/GBA.h>
#import <main/Main.hh>
#import <OptionView.hh>

#include <fs/sys.hh>

// Emulator Includes
#include <util/time/sys.hh>
#include <base/Base.hh>
#include <base/iphone/private.hh>
#include <mem/cartridge.h>
#include "GBALink.h"

#ifdef CONFIG_INPUT
#include <input/Input.hh>
#endif

#include <gambatte.h>

extern bool isGBAROM;

extern int app_argc;
extern char **app_argv;


@interface GBAEmulatorCore ()

@property (strong, nonatomic) UIScreen *screen;

@end

#pragma mark - EAGLView

// A class extension to declare private methods
@interface EAGLView ()

@property (nonatomic, retain) EAGLContext *context;

@end

@implementation EAGLView

@synthesize context;

// Implement this to override the default layer class (which is [CALayer class]).
// We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

-(id)initGLES
{
	CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    
#if !defined(__ARM_ARCH_6K__)
	using namespace Base;
	if(usingiOS4)
	{
        CGFloat scale = [[[GBAEmulatorCore sharedCore] screen] scale];
        eaglLayer.contentsScale = scale;
        pointScale = scale;
        currWin = mainWin;
	}
#endif
    
	self.multipleTouchEnabled = YES;
	eaglLayer.opaque = YES;
	if(!Base::useMaxColorBits)
	{
		logMsg("using RGB565 surface");
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        kEAGLColorFormatRGB565, kEAGLDrawablePropertyColorFormat, nil];
		//[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking
	}
    
	context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
	assert(context);
	int ret = [EAGLContext setCurrentContext:context];
	assert(ret);
	/*if (!context || ![EAGLContext setCurrentContext:context])
     {
     [self release];
     return nil;
     }*/
	Base::mainContext = context;
	
	Base::displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(drawView)];
	Base::displayLinkActive = YES;
	[Base::displayLink setFrameInterval:1];
	[Base::displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	
	[EAGLContext setCurrentContext:context];
	//[self destroyFramebuffer];
	[self createFramebuffer];
    
	//[self drawView];
    
	return self;
}

- (CGSize)screenSize
{
    return CGSizeMake(320, 240);
}

#ifdef CONFIG_BASE_IPHONE_NIB
// Init from NIB
- (id)initWithCoder:(NSCoder*)coder
{
	if ((self = [super initWithCoder:coder]))
	{
		self = [self initGLES];
	}
	return self;
}
#endif

// Init from code
-(id)initWithFrame:(CGRect)frame
{
	logMsg("entered initWithFrame");
	if((self = [super initWithFrame:frame]))
	{
		self = [self initGLES];
	}
	logMsg("exiting initWithFrame");
	return self;
}

extern void CPULoop(GBASys &gba, bool renderGfx, bool processGfx, bool renderAudio);

- (void)drawView
{
	/*TimeSys now;
     now.setTimeNow();
     logMsg("frame time stamp %f, duration %f, now %f", displayLink.timestamp, displayLink.duration, (float)now);*/
	//[EAGLContext setCurrentContext:context];
	//glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	if(unlikely(!Base::displayLinkActive) || [[GBAEmulatorCore sharedCore] isPaused])
    {
		return;
    }
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
    {
        return;
    }
    
	//logMsg("screen update");
    
    //DammCFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    //CPULoop(gGba, false, false, true);
    Base::runEngine(Base::displayLink.timestamp);
    
    //DLog(@"Frame Length: %dms", (int)((CFAbsoluteTimeGetCurrent() - startTime) * 1000));
    
	if(!Base::gfxUpdate)
	{
		Base::stopAnimation();
	}
}


- (void)layoutSubviews
{
	logMsg("in layoutSubviews");
	[self drawView];
	//logMsg("exiting layoutSubviews");
}


- (BOOL)createFramebuffer
{
	logMsg("creating OpenGL framebuffers");
    glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
    
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
            
	if(Base::USE_DEPTH_BUFFER)
	{
		glGenRenderbuffersOES(1, &depthRenderbuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
		glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	}
    
	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		logMsg("failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
	
	Base::openglViewIsInit = 1;
	return YES;
}


- (void)destroyFramebuffer
{
	logMsg("deleting OpenGL framebuffers");
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
    
	if(depthRenderbuffer)
	{
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
	
	Base::openglViewIsInit = 0;
}

- (void)dealloc
{
	if ([EAGLContext currentContext] == context)
	{
		[EAGLContext setCurrentContext:nil];
	}
    
}

#ifdef CONFIG_INPUT

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	using namespace Base;
	using namespace Input;
	for(UITouch* touch in touches)
	{
		iterateTimes((uint)Input::maxCursors, i) // find a free touch element
		{
			if(Input::m[i].touch == nil)
			{
				auto &p = Input::m[i];
				p.touch = touch;
				CGPoint startTouchPosition = [touch locationInView:self.superview.superview.superview];
				auto pos = pointerPos(startTouchPosition.x * pointScale, startTouchPosition.y * pointScale);
				p.s.inWin = 1;
				p.dragState.pointerEvent(Input::Pointer::LBUTTON, PUSHED, pos);
                
                if (isGBAROM)
                {
                    Input::onInputEvent_GBA(Input::Event((unsigned int)i, Event::MAP_POINTER, Input::Pointer::LBUTTON, PUSHED, pos.x, pos.y, true, nullptr));
                }
                else
                {
                    Input::onInputEvent_GBC(Input::Event((unsigned int)i, Event::MAP_POINTER, Input::Pointer::LBUTTON, PUSHED, pos.x, pos.y, true, nullptr));
                }
                
				
				break;
			}
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	using namespace Base;
	using namespace Input;
	for(UITouch* touch in touches)
	{
		iterateTimes((uint)Input::maxCursors, i) // find the touch element
		{
			if(Input::m[i].touch == touch)
			{
				auto &p = Input::m[i];
				CGPoint currentTouchPosition = [touch locationInView:self.superview.superview.superview];
				auto pos = pointerPos(currentTouchPosition.x * pointScale, currentTouchPosition.y * pointScale);
				p.dragState.pointerEvent(Input::Pointer::LBUTTON, MOVED, pos);
                
                if (isGBAROM)
                {
                    Input::onInputEvent_GBA(Input::Event((unsigned int)i, Event::MAP_POINTER, Input::Pointer::LBUTTON, MOVED, pos.x, pos.y, true, nullptr));
                }
                else
                {
                    Input::onInputEvent_GBC(Input::Event((unsigned int)i, Event::MAP_POINTER, Input::Pointer::LBUTTON, MOVED, pos.x, pos.y, true, nullptr));
                }
				
				break;
			}
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	using namespace Base;
	using namespace Input;
	for(UITouch* touch in touches)
	{
		iterateTimes((uint)Input::maxCursors, i) // find the touch element
		{
			if(Input::m[i].touch == touch)
			{
				auto &p = Input::m[i];
				p.touch = nil;
				p.s.inWin = 0;
				CGPoint currentTouchPosition = [touch locationInView:self.superview.superview.superview];
				auto pos = pointerPos(currentTouchPosition.x * pointScale, currentTouchPosition.y * pointScale);
				p.dragState.pointerEvent(Input::Pointer::LBUTTON, RELEASED, pos);
                
                if (isGBAROM)
                {
                    Input::onInputEvent_GBA(Input::Event((unsigned int)i, Event::MAP_POINTER, Input::Pointer::LBUTTON, RELEASED, pos.x, pos.y, true, nullptr));
                }
                else
                {
                    Input::onInputEvent_GBC(Input::Event((unsigned int)i, Event::MAP_POINTER, Input::Pointer::LBUTTON, RELEASED, pos.x, pos.y, true, nullptr));
                }
                
				
				break;
			}
		}
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self touchesEnded:touches withEvent:event];
}

#if defined(CONFIG_BASE_IOS_KEY_INPUT) || defined(CONFIG_INPUT_ICADE)
- (BOOL)canBecomeFirstResponder { return YES; }

- (BOOL)hasText { return NO; }

- (void)insertText:(NSString *)text
{
#ifdef CONFIG_INPUT_ICADE
	if(Base::iCade.isActive())
		Base::iCade.insertText(text);
#endif
	//logMsg("got text %s", [text cStringUsingEncoding: NSUTF8StringEncoding]);
}

- (void)deleteBackward { }

#ifdef CONFIG_INPUT_ICADE
- (UIView*)inputView
{
	return Base::iCade.dummyInputView;
}
#endif
#endif // defined(CONFIG_BASE_IOS_KEY_INPUT) || defined(CONFIG_INPUT_ICADE)

#endif

@end

#pragma mark - Emulator Core


NSString *const GBAROMDidSaveDataNotification = @"GBAROMDidSaveDataNotification";

void writeSaveFileForCurrentROMToDisk();

@interface GBAEmulatorCore ()

@property (readwrite, strong, nonatomic) EAGLView *eaglView;
@property (assign, nonatomic, readwrite, getter=isPaused) BOOL paused;

@property (copy, nonatomic) NSSet *previousButtons;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) dispatch_queue_t update_save_file_queue;
@property (strong, nonatomic) NSTimer *updateSaveFileTimer;

@end

@implementation GBAEmulatorCore

+ (instancetype)sharedCore {
    static GBAEmulatorCore *sharedCore = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCore = [[self alloc] init];
    });
    return sharedCore;
}

- (id)init {
    if (self = [super init])
    {
        _paused = YES;
        
        self.motionManager = [[CMMotionManager alloc] init];
        
        self.update_save_file_queue = dispatch_queue_create("GBA4iOS Update Save File Queue", DISPATCH_QUEUE_SERIAL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSettings:) name:GBASettingsDidChangeNotification object:nil];
        
        [self prepareEmulation];
    }
    return self;
}

- (void)prepareEmulation
{
    Base::mainApp = self;
    
    optionAutoSaveState = 0;
    optionConfirmAutoLoadState = NO;
    optionHideStatusBar = YES;
    optionAspectRatio.val = 2;
    
    [self updateSettings:nil];
}

- (void)updateEAGLViewForSize:(CGSize)size screen:(UIScreen *)screen
{
    using namespace Base;
    
    self.screen = screen;
    
    CGFloat scale = [screen scale];
    
	mainWin.w = mainWin.rect.x2 = size.width * scale;
	mainWin.h = mainWin.rect.y2 = size.height * scale;
    
    // Controls size of built-in controls. Since we aren't using these, we just set these to a valid number so the assert doesn't crash us.
	Gfx::viewMMWidth_ = 50;
	Gfx::viewMMHeight_ = 50;
    
    logMsg("set screen MM size %dx%d", Gfx::viewMMWidth_, Gfx::viewMMHeight_);
	currWin = mainWin;
    
    //printf("Pixel size: %dx%d", Gfx::viewPixelWidth(), Gfx::viewPixelHeight());
    
    if (self.eaglView == nil)
    {
        // Create the OpenGL ES view
        glView = [[EAGLView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
        
        self.eaglView = glView;
    }
    else
    {
        glView.frame = CGRectMake(0, 0, size.width, size.height);
        [glView.superview layoutIfNeeded];
        
        CGFloat previousScale = self.eaglView.layer.contentsScale;
        
        if (previousScale != screen.scale)
        {
            self.eaglView.layer.contentsScale = screen.scale;
            Base::pointScale = screen.scale;
        }
        
        // Update framebuffer for new size (or else graphics are slightly blurred)
        [Base::glView destroyFramebuffer];
        [Base::glView createFramebuffer];
        Gfx::setOutputVideoMode(mainWin);
        
        bool fastForwardEnabled = emuView.ffGuiTouch;
        
        startGameFromMenu();
        
        emuView.ffGuiTouch = fastForwardEnabled;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

extern void startGameFromMenu();
extern void applyGBPalette(uint idx);

- (void)updateSettings:(NSNotification *)notification
{
    NSString *settingsKey = notification.userInfo[@"key"];
    
    if ([settingsKey isEqualToString:GBASettingsFrameSkipKey])
    {
        NSInteger frameskip = [[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsFrameSkipKey];
        
        if (frameskip < 0)
        {
            frameskip = EmuSystem::optionFrameSkipAuto;
        }
        
        optionFrameSkip.val = frameskip;
    }
    else if ([settingsKey isEqualToString:GBASettingsSelectedColorPaletteKey])
    {
        applyGBPalette((uint)[notification.userInfo[@"value"] integerValue]);
    }
    else if ([settingsKey isEqualToString:GBASettingsPreferExternalAudioKey])
    {
        [self updateAudioSession];
    }
    
}

- (void)updateAudioSession
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsPreferExternalAudioKey])
    {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient withOptions:0 error:nil];
    }
    else
    {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient withOptions:0 error:nil];
    }
}

- (void)setRom:(GBAROM *)rom
{
    _rom = rom;
    
    if (rom.type == GBAROMTypeGBA)
    {
        isGBAROM = YES;
    }
    else
    {
        isGBAROM = NO;
    }
}

double TimeMach::timebaseNSec = 0, TimeMach::timebaseUSec = 0,
TimeMach::timebaseMSec = 0, TimeMach::timebaseSec = 0;

- (void)startEmulation
{
    optionSound.val = 0;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        doOrExit(logger_init());
        TimeMach::setTimebase();
        
#ifdef CONFIG_FS
        FsPosix::changeToAppDir(app_argv[0]);
#endif
        
#ifdef CONFIG_INPUT
        doOrExit(Input::init());
#endif
        
#ifdef CONFIG_AUDIO
        Audio::initSession();
#endif
        
        Base::grayColorSpace = CGColorSpaceCreateDeviceGray();
        Base::rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        
        [self prepareEmulation];
        
        [self updateAudioSession];
        
    });
    
    [self endEmulation];
    
    if (isGBAROM)
    {
        doOrExit(Base::onInit_GBA(app_argc, app_argv));
    }
    else
    {
        doOrExit(Base::onInit_GBC(app_argc, app_argv));
        applyGBPalette((uint)[[NSUserDefaults standardUserDefaults] integerForKey:GBASettingsSelectedColorPaletteKey]);
    }
    
    Audio::closePcm();
    
    Base::engineInit();
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    Base::setAutoOrientation(1);
    
    using namespace Base;
    using namespace Input;
    
    optionRtcEmulation = RTC_EMU_ON; // Some hacked games use the RealTimeClock even when the game they're based off of doesn't (ex: Pokemon Liquid Crystal), so we always have it enabled.
    
    GameFilePicker::onSelectFile([self.rom.filepath UTF8String], [self touchForTouchState:RELEASED]);
    
    [self loadCheats];
    
}

- (void)pauseEmulation
{
    self.paused = YES;
    
	if(!optionFrameSkip.isConst)
    {
		Gfx::setVideoInterval(1);
    }
	Base::setRefreshRate(Base::REFRESH_RATE_DEFAULT);
	Base::displayNeedsUpdate();
    
    using namespace Base;
	appState = APP_PAUSED;
	Base::stopAnimation();
	Base::onExit(1);
#ifdef CONFIG_INPUT_ICADE
	iCade.didEnterBackground();
#endif
	glFinish();
	[glView destroyFramebuffer];
    
    [[AVAudioSession sharedInstance] setActive:NO error:nil];
}

- (void)resumeEmulation
{
    self.paused = NO;
    
    if(!optionFrameSkip.isConst && (uint)optionFrameSkip != EmuSystem::optionFrameSkipAuto)
    {
        Gfx::setVideoInterval((int)optionFrameSkip + 1);
    }
	Base::setRefreshRate(EmuSystem::vidSysIsPAL() ? 50 : 60);
	Base::displayNeedsUpdate();
    
    if (shouldPlayGameAudio())
    {
        optionSound.val = 1;
    }
    else
    {
        optionSound.val = 0;
    }
    
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
    
    Gfx::setOutputVideoMode(mainWin);
}

- (void)endEmulation
{
    EmuSystem::closeGame(NO);
}

#pragma mark - Audio

bool shouldPlayGameAudio()
{
    if ([[AVAudioSession sharedInstance] isOtherAudioPlaying] && [[NSUserDefaults standardUserDefaults] boolForKey:GBASettingsPreferExternalAudioKey])
    {
        return NO;
    }
    
    return YES;
}

#pragma mark - Filters

- (void)applyEmulationFilter:(GBAEmulationFilter)emulationFilter
{
    optionImgFilter.val = emulationFilter;
    
    if(emuView.disp.image())
    {
        emuView.vidImg.setFilter(emulationFilter);
    }
    
}

#pragma mark - Button Pressing

extern SysVController vController;

- (void)pressButtons:(NSSet *)buttons
{
    for (NSNumber *button in buttons)
    {
        if ([button isEqualToNumber:@(GBAControllerButtonFastForward)] || [button isEqualToNumber:@(GBAControllerButtonSustainButton)] || [button isEqualToNumber:@(GBAControllerButtonMenu)])
        {
            continue;
        }
        
        vController.inputAction(Input::PUSHED, [button unsignedIntValue]);
    }
    
}

- (void)releaseButtons:(NSSet *)buttons
{
    for (NSNumber *button in buttons)
    {
        if ([button isEqualToNumber:@(GBAControllerButtonFastForward)] || [button isEqualToNumber:@(GBAControllerButtonSustainButton)] || [button isEqualToNumber:@(GBAControllerButtonMenu)])
        {
            continue;
        }
        
        vController.inputAction(Input::RELEASED, [button unsignedIntValue]);
    }
    
}

- (const Input::Event)touchForTouchState:(uint)touchState {
    using namespace Base;
    using namespace Input;
    
    return Input::Event(0, Event::MAP_POINTER, Input::Pointer::LBUTTON, touchState, 0, 0, true, nullptr);
}

#pragma mark - Fast Forwarding

extern EmuView emuView;

- (void)startFastForwarding
{
    emuView.ffGuiTouch = true;
}

- (void)stopFastForwarding
{
    emuView.ffGuiTouch = false;
}

#pragma mark - Saving

void updateSaveFileForCurrentROM()
{
    // Using performSelector:afterDelay: or NSTimer on the main thread slows down emulation when saving.
    dispatch_async([GBAEmulatorCore sharedCore].update_save_file_queue, ^{
        [[GBAEmulatorCore sharedCore].updateSaveFileTimer invalidate];
        [GBAEmulatorCore sharedCore].updateSaveFileTimer = [NSTimer timerWithTimeInterval:1 target:[GBAEmulatorCore sharedCore] selector:@selector(writeSaveFileForCurrentROMToDisk) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:[GBAEmulatorCore sharedCore].updateSaveFileTimer forMode:NSDefaultRunLoopMode];
    });
}

- (void)writeSaveFileForCurrentROMToDisk
{
    NSData *beforeData = [NSData dataWithContentsOfFile:self.rom.saveFileFilepath];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self.rom.saveFileFilepath error:nil];
    
    if (isGBAROM)
    {
        EmuSystem::saveBackupMem_GBA();
    }
    else
    {
        EmuSystem::saveBackupMem_GBC();
    }
    
    NSData *afterData = [NSData dataWithContentsOfFile:self.rom.saveFileFilepath];
    
    if ([beforeData isEqualToData:afterData])
    {
        // The data didn't really change, so we set the metadata back to what it was before so the sync manager knows it hasn't changed (because the sync manager compares metadata to see if it should sync a file)
        [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:self.rom.saveFileFilepath error:nil];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GBAROMDidSaveDataNotification object:self.rom];
}

extern bool useCustomSavePath;

- (void)setCustomSavePath:(NSString *)customSavePath
{
    if ([customSavePath isEqualToString:_customSavePath])
    {
        return;
    }
    
    _customSavePath = [customSavePath copy];
    
    if (customSavePath)
    {
        useCustomSavePath = true;
    }
    else
    {
        useCustomSavePath = false;
    }
}

const char * customSavePath()
{
    return [[[GBAEmulatorCore sharedCore] customSavePath] UTF8String];
}


extern GBASys gGba;
extern gambatte::GB gbEmu;

#pragma mark - Save States

- (void)saveStateToFilepath:(NSString *)filepath
{
    if (isGBAROM)
    {
        CPUWriteState(gGba, [filepath UTF8String]);
    }
    else
    {
        gbEmu.saveState(/*screenBuff*/0, 160, [filepath UTF8String]);
    }
}

- (void)loadStateFromFilepath:(NSString *)filepath
{
    if (isGBAROM)
    {
        CPUReadState(gGba, [filepath UTF8String]);
    }
    else
    {
        gbEmu.loadState([filepath UTF8String]);
    }
}

#pragma mark - Cheats

- (NSString *)cheatsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *cheatsParentDirectory = [documentsDirectory stringByAppendingPathComponent:@"Cheats"];
    NSString *cheatsDirectory = [cheatsParentDirectory stringByAppendingPathComponent:self.rom.name];
        
    [[NSFileManager defaultManager] createDirectoryAtPath:cheatsDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return cheatsDirectory;
}

// Not a property because we need to make sure it's always updated with latest changes
- (NSArray *)cheatsArray
{
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self cheatsDirectory] error:nil];
    
    NSMutableArray *cheats = [NSMutableArray arrayWithCapacity:contents.count];
    
    @autoreleasepool
    {
        for (NSString *filename in contents)
        {
            if (![filename.pathExtension isEqualToString:@"gbacheat"])
            {
                continue;
            }
            
            NSString *filepath = [[self cheatsDirectory] stringByAppendingPathComponent:filename];
            GBACheat *cheat = [GBACheat cheatWithContentsOfFile:filepath];
            [cheats addObject:cheat];
        }
    }
    
    return cheats;
}

- (NSInteger)initialCodeIndexOfCheat:(GBACheat *)initialCheat inCheatsArray:(NSArray *)cheatsArray
{
    __block NSInteger actualIndex = 0;
    
    [[cheatsArray copy] enumerateObjectsUsingBlock:^(GBACheat *cheat, NSUInteger idx, BOOL *stop)
     {
         if (![cheat.name isEqualToString:initialCheat.name])
         {
             actualIndex = actualIndex + [cheat.codes count];
         }
         else
         {
             *stop = YES;
         }
     }];
        
    return actualIndex;
}

- (BOOL)loadCheats
{
    NSDictionary *enabledCheatsDictionary = [NSDictionary dictionaryWithContentsOfFile:[[self cheatsDirectory] stringByAppendingPathComponent:@"enabledCheats.plist"]];
    
    if (isGBAROM)
    {
        cheatsDeleteAll(gGba.cpu, false);
    }
    else
    {
        return [self updateGBCCheats];
    }
    NSArray *cheats = [self cheatsArray];
    @autoreleasepool
    {
        for (GBACheat *cheat in cheats)
        {
            if (![self addCheat:cheat])
            {
                return NO;
            }
            
            if (![enabledCheatsDictionary[cheat.uid] boolValue])
            {
                // So we don't read from disk for EVERY disabled cheat, we use a cached version
                NSInteger index = [self initialCodeIndexOfCheat:cheat inCheatsArray:cheats];
                [self disableCheat:cheat atIndex:index];
            }
        }
    }
    
    return YES;
}

- (BOOL)addCheat:(GBACheat *)cheat
{
    NSUInteger cheatCodeLength = 0;
    
    switch (cheat.type) {
        case GBACheatCodeTypeCodeBreaker:
            cheatCodeLength = 12ul;
            break;
            
        case GBACheatCodeTypeGameSharkV3:
            cheatCodeLength = 16ul;
            break;
            
        case GBACheatCodeTypeActionReplay:
            cheatCodeLength = 16ul;
            break;
            
        case GBACheatCodeTypeGameSharkGBC:
            cheatCodeLength = 8ul;
            break;
            
        case GBACheatCodeTypeGameGenie:
            cheatCodeLength = 9ul;
            break;
    }
    
    // Must have at least one code, and it must be a complete code
    if ([cheat.codes count] < 1 || [(NSString *)[cheat.codes lastObject] length] % cheatCodeLength != 0)
    {
        return NO;
    }
    
    if (!isGBAROM)
    {
        return [self updateGBCCheats];
    }
    
    NSMutableString *allGamesharkGBCCodes = [NSMutableString string];
    NSMutableString *allGameGenieCodes = [NSMutableString string];
    
    __block BOOL succeeded = YES;
    [cheat.codes enumerateObjectsUsingBlock:^(NSString *code, NSUInteger index, BOOL *stop) {
        NSString *title = [NSString stringWithFormat:@"%@ %lull", cheat.name, (unsigned long)index];
        
        switch (cheat.type)
        {
            case GBACheatCodeTypeCodeBreaker: {
                // Unlike the add Gameshark method, VBA's add Code Breaker method requires the space to be in the code
                NSMutableString *modifiedCode = [code mutableCopy];
                [modifiedCode insertString:@" " atIndex:8];
                
                succeeded = cheatsAddCBACode(gGba.cpu, [modifiedCode UTF8String], [title UTF8String]);
                break;
            }
                
            case GBACheatCodeTypeGameSharkV3:
                succeeded = cheatsAddGSACode(gGba.cpu, [code UTF8String], [title UTF8String], true);
                break;
                
            // Action Replay and GameShark v3 codes are interchangable
            case GBACheatCodeTypeActionReplay:
                succeeded = cheatsAddGSACode(gGba.cpu, [code UTF8String], [title UTF8String], true);
                break;
                
            default:
                break;
        }
        
        if (!succeeded)
        {
            *stop = YES;
        }
    }];
    
    return succeeded;
}

- (void)removeCheat:(GBACheat *)cheat
{
    // Too many edge-cases to code for when deleting codes, so we just reload them every time.
    // Trust me, the alternative code would just be complicated, and you probably wouldn't know about some of the bugs until they pop up unproducibly.
    
    [self updateCheats];
}

- (void)enableCheat:(GBACheat *)cheat
{
    if (!isGBAROM)
    {
        [self updateGBCCheats];
        return;
    }
    
    NSInteger index = [self initialCodeIndexOfCheat:cheat inCheatsArray:[self cheatsArray]];
    [cheat.codes enumerateObjectsUsingBlock:^(NSString *code, NSUInteger enumertionIndex, BOOL *stop) {
        cheatsEnable((unsigned int)(index + enumertionIndex));
    }];
}

- (void)disableCheat:(GBACheat *)cheat
{
    if (!isGBAROM)
    {
        [self updateGBCCheats];
        return;
    }
    
    NSInteger index = [self initialCodeIndexOfCheat:cheat inCheatsArray:[self cheatsArray]];
    return [self disableCheat:cheat atIndex:index];
}

- (void)disableCheat:(GBACheat *)cheat atIndex:(NSInteger)index
{
    if (!isGBAROM)
    {
        [self updateGBCCheats];
        return;
    }
    
    [cheat.codes enumerateObjectsUsingBlock:^(NSString *code, NSUInteger enumertionIndex, BOOL *stop) {
        cheatsDisable(gGba.cpu, (unsigned int)(index + enumertionIndex));
    }];
}

- (BOOL)updateCheats
{
    if (!isGBAROM)
    {
        return [self updateGBCCheats];
    }
    
    cheatsDeleteAll(gGba.cpu, true);
    return [self loadCheats];
}

- (BOOL)updateGBCCheats
{
    NSArray *cheats = [self cheatsArray];
    
    NSString *gameSharkCheats = [self GBCCheatsStringFromCheatsArray:cheats forCheatType:GBACheatCodeTypeGameSharkGBC];
    NSString *gameGenieCheats = [self GBCCheatsStringFromCheatsArray:cheats forCheatType:GBACheatCodeTypeGameGenie];
    
    gbEmu.setGameShark([gameSharkCheats UTF8String]);
    gbEmu.setGameGenie([gameGenieCheats UTF8String]);
    
    return YES;
}

- (NSString *)GBCCheatsStringFromCheatsArray:(NSArray *)cheats forCheatType:(GBACheatCodeType)type
{
    NSDictionary *enabledCheatsDictionary = [NSDictionary dictionaryWithContentsOfFile:[[self cheatsDirectory] stringByAppendingPathComponent:@"enabledCheats.plist"]];
    
    NSMutableString *cheatsString = [NSMutableString string];
    
    for (GBACheat *cheat in cheats)
    {
        if (cheat.type == type && [enabledCheatsDictionary[cheat.uid] boolValue])
        {
            for (NSString *code in cheat.codes)
            {
                NSMutableString *modifiedCode = [code mutableCopy];
                
                if (type == GBACheatCodeTypeGameGenie)
                {
                    [modifiedCode insertString:@"-" atIndex:3];
                    [modifiedCode insertString:@"-" atIndex:7];
                }
                
                [cheatsString appendFormat:@"%@;", modifiedCode];
            }
        }
    }
    
    return cheatsString;
}

#pragma mark - Multiplayer

#ifdef USE_BLUETOOTH

int GBALinkSendDataToPlayerAtIndex(int index, const char *data, size_t size)
{
    NSData *outputData = [NSData dataWithBytes:(const void *)data length:size];
    int sentDataLength = (int)[[GBABluetoothLinkManager sharedManager] sendData:outputData toPlayerAtIndex:index];
    
    /*if (sentDataLength > 0)
    {
        NSLog(@"Sent data! (%d)", sentDataLength);
    }
    else
    {
        NSLog(@"Failed to send data :(");
    }*/
    
    return sentDataLength;
}

int GBALinkReceiveDataFromPlayerAtIndex(int index, char *data, size_t maxSize)
{
    NSData *receivedData = nil;
    int receivedDataLength = (int)[[GBABluetoothLinkManager sharedManager] receiveData:&receivedData withMaxSize:maxSize fromPlayerAtIndex:index];
    
    [receivedData getBytes:data];
    
    /*if (receivedDataLength > 0)
    {
        NSLog(@"Received data! (%d)", receivedDataLength);
    }*/
    
    return receivedDataLength;
}

bool GBALinkWaitForLinkDataWithTimeout(int timeout)
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    bool success = (bool)[[GBABluetoothLinkManager sharedManager] waitForLinkDataWithTimeout:timeout];

    NSLog(@"Wireless Delay: %g seconds", CFAbsoluteTimeGetCurrent() - startTime);
    
    /*if (success)
    {
        NSLog(@"Has Data");
    }
    else
    {
        NSLog(@"Timeout");
    }*/
    
    return success;
}

#else

int GBALinkSendDataToPlayerAtIndex(int index, const char *data, size_t size)
{
    int sentDataLength = (int)[[GBALinkManager sharedManager] sendData:data withSize:size toPlayerAtIndex:index];
    
    if (sentDataLength > 0)
    {
        //NSLog(@"Sent data! (%@)", [NSData dataWithBytes:(const void *)data length:size]);
    }
    else
    {
        NSLog(@"Failed to send data :(");
    }
    
    return sentDataLength;
}

int GBALinkReceiveDataFromPlayerAtIndex(int index, char *data, size_t maxSize)
{
    int receivedDataLength = (int)[[GBALinkManager sharedManager] receiveData:data withMaxSize:maxSize fromPlayerAtIndex:index];
    
    if (receivedDataLength > 0)
    {
        //NSLog(@"Received data! (%@)", [NSData dataWithBytes:(const void *)data length:maxSize]);
    }
    
    return receivedDataLength;
}

bool GBALinkWaitForLinkDataWithTimeout(int timeout)
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    bool success = (bool)[[GBALinkManager sharedManager] waitForLinkDataWithTimeout:timeout];
    
    //NSLog(@"Wireless Delay: %dms", (int)((CFAbsoluteTimeGetCurrent() - startTime) * 1000));
    
    /*if (success)
    {
        NSLog(@"Has Data %dms", (int)((CFAbsoluteTimeGetCurrent() - startTime) * 1000));
    }
    else
    {
        NSLog(@"Timeout");
    }*/
    
    return success;
}

bool GBALinkHasDataAvailable(int *index)
{
    BOOL dataAvailable = [[GBALinkManager sharedManager] hasLinkDataAvailable:index];
    
    if (dataAvailable)
    {
        //NSLog(@"Data Available");
    }
    
    return dataAvailable;
}

#endif

static OSSpinLock _lock = OS_SPINLOCK_INIT;

void GBALinkLock()
{
    OSSpinLockLock(&_lock);
}

void GBALinkUnlock()
{
    OSSpinLockUnlock(&_lock);
}

const char *GBADataHexadecimalRepresentation(char *data, int size)
{
    return [[[NSData dataWithBytes:(const void *)data length:size] description] UTF8String];
}

void GBALog(const char *message, ...)
{
    va_list arg;
    int done;
    
    va_start (arg, message);
    
    NSLogv([NSString stringWithFormat:@"%s", message], arg);
    
    va_end (arg);
}

void systemScreenMessage(const char *message)
{
    DLog("%s", message);
}

static const int length = 256;

- (void)startLinkWithConnectionType:(GBALinkConnectionType)connectionType peerType:(GBALinkPeerType)peerType completion:(void (^)(BOOL))completion
{
    SetLinkTimeout(1000);
    EnableSpeedHacks(false);
    
    if (peerType == GBALinkPeerTypeServer)
    {
        EnableLinkServer(true,  1);
    }
    else
    {
        SetLinkServerHost("192.168.1.102");
    }
    
    char localhost[length];
    GetLinkServerHost(localhost, length);
    
    DLog(@"IP Address: %s", localhost);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        LinkMode linkMode = (connectionType == GBALinkConnectionTypeLinkCable) ? LINK_CABLE_SOCKET : LINK_RFU_SOCKET;
        
        ConnectionState state = InitLink(linkMode);
        
        while (state == LINK_NEEDS_UPDATE)
        {
            char emptyMessage[256];
            state = ConnectLinkUpdate(emptyMessage, 256);
        }
        
        if (completion)
        {
            BOOL success = (state == LINK_OK);
            completion(success);
        }
        
        if (connectionType == GBALinkConnectionTypeWirelessAdapter)
        {
            GBARunWirelessAdaptorLoop();
        }
        
    });
    
}

- (void)stopLink
{
    CloseLink();
}

- (void)startServer
{
    SetLinkTimeout(1000);
    EnableSpeedHacks(false);
    EnableLinkServer(true,  1);
    
    __block ConnectionState state = InitLink(LINK_RFU_SOCKET);
    
    char localhost[length];
    GetLinkServerHost(localhost, length);
    
    NSString *message = [NSString stringWithFormat:@"Position: %i\nServer IP Address: %s", GetLinkPlayerId(), localhost];
    DLog(@"%@", message);
    
    while (state == LINK_NEEDS_UPDATE) {
        // Ask the core for updates
        char emptyMessage[length];
        state = ConnectLinkUpdate(emptyMessage, length);
    }
    
    message = [NSString stringWithFormat:@"Position: %i\nServer IP Address: %s", GetLinkPlayerId(), localhost];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connected!"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    });
    
    switch (state) {
        case LINK_OK:
            DLog(@"Link OK!");
            break;
            
        case LINK_ERROR:
            DLog(@"Link Error :((");
            break;
            
        case LINK_NEEDS_UPDATE:
            DLog(@"Link needs update!");
            break;
            
        case LINK_ABORT:
            DLog(@"Link abort");
            break;
            
        default:
            break;
    }
    
    DLog(@"Starting RFU Loop");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        GBARunWirelessAdaptorLoop();
    });
}

- (void)connectToServer
{
    SetLinkTimeout(1000);
    EnableSpeedHacks(false);
    SetLinkServerHost("192.168.29.168");
    
    __block ConnectionState state = InitLink(LINK_RFU_SOCKET);
    
    while (state == LINK_NEEDS_UPDATE) {
        // Ask the core for updates
        char emptyMessage[length];
        state = ConnectLinkUpdate(emptyMessage, length);
    }
    
    char localhost[length];
    GetLinkServerHost(localhost, length);
    
    NSString *message = [NSString stringWithFormat:@"Position: %i\nServer IP Address: %s", GetLinkPlayerId(), localhost];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connected!"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    });
    
    switch (state) {
        case LINK_OK:
            DLog(@"Link OK!");
            break;
            
        case LINK_ERROR:
            DLog(@"Link Error :((");
            break;
            
        case LINK_NEEDS_UPDATE:
            DLog(@"Link needs update!");
            break;
            
        case LINK_ABORT:
            DLog(@"Link abort");
            break;
            
        default:
            break;
    }
    
    DLog(@"Starting RFU Loop");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        GBARunWirelessAdaptorLoop();
    });
}

#pragma mark - Wario Ware Twisted

void startDeviceMotionDetection()
{
    [[GBAEmulatorCore sharedCore].motionManager startGyroUpdates];
    
    if ([[GBAEmulatorCore sharedCore].delegate respondsToSelector:@selector(emulatorCore:didEnableGyroscopeForROM:)])
    {
        [[GBAEmulatorCore sharedCore].delegate emulatorCore:[GBAEmulatorCore sharedCore] didEnableGyroscopeForROM:[GBAEmulatorCore sharedCore].rom];
    }
}

void stopDeviceMotionDetection()
{
    [[GBAEmulatorCore sharedCore].motionManager stopGyroUpdates];
}

uint16_t deviceGetGyroRotationRateZ()
{
    // If gyro isn't enabled, it'll just return nil, which is what we want since the rotationRate will then also be 0.
    CMGyroData *gyroData = [[GBAEmulatorCore sharedCore].motionManager gyroData];
    
    return 0x6C0 - (gyroData.rotationRate.z * 25);
}

UIKIT_EXTERN void AudioServicesStopSystemSound(int);
UIKIT_EXTERN void AudioServicesPlaySystemSoundWithVibration(int, id, NSDictionary *);


void rumbleDevice(bool vibrate)
{
    // Vibration duration isn't long enough for the vibration to actually be performed. Workaround?  
}

#pragma mark - Main App

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
- (void)applicationWillTerminate:(NSNotification *)notification
{
	[self endEmulation];
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


@end
