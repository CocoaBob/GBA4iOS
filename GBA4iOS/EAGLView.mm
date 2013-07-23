//
//  EAGLView.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "MainApp.h"
#import "EAGLView.h"

#include <base/common/funcs.h>

#import "SharedNamespace.hh"

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
		logMsg("testing for Retina Display");
		if([UIScreen mainScreen].scale == 2.0)
		{
			logMsg("running on Retina Display");
			eaglLayer.contentsScale = 2.0;
			pointScale = 2;
			mainWin.rect.x2 *= 2;
			mainWin.rect.y2 *= 2;
			mainWin.w *= 2;
			mainWin.h *= 2;
			currWin = mainWin;
	    }
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
	//displayLink.paused = YES;
	Base::displayLinkActive = YES;
	[Base::displayLink setFrameInterval:1];
	[Base::displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	
	[EAGLContext setCurrentContext:context];
	//[self destroyFramebuffer];
	[self createFramebuffer];
    
	//[self drawView];
    
	return self;
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

- (void)drawView
{
	/*TimeSys now;
     now.setTimeNow();
     logMsg("frame time stamp %f, duration %f, now %f", displayLink.timestamp, displayLink.duration, (float)now);*/
	//[EAGLContext setCurrentContext:context];
	//glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	if(unlikely(!Base::displayLinkActive))
		return;
    
	//logMsg("screen update");
	Base::runEngine(Base::displayLink.timestamp);
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
				CGPoint startTouchPosition = [touch locationInView:self];
				auto pos = pointerPos(startTouchPosition.x * pointScale, startTouchPosition.y * pointScale);
				p.s.inWin = 1;
				p.dragState.pointerEvent(Input::Pointer::LBUTTON, PUSHED, pos);
				Input::onInputEvent(Input::Event(i, Event::MAP_POINTER, Input::Pointer::LBUTTON, PUSHED, pos.x, pos.y, true, nullptr));
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
				CGPoint currentTouchPosition = [touch locationInView:self];
				auto pos = pointerPos(currentTouchPosition.x * pointScale, currentTouchPosition.y * pointScale);
				p.dragState.pointerEvent(Input::Pointer::LBUTTON, MOVED, pos);
				Input::onInputEvent(Input::Event(i, Event::MAP_POINTER, Input::Pointer::LBUTTON, MOVED, pos.x, pos.y, true, nullptr));
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
				CGPoint currentTouchPosition = [touch locationInView:self];
				auto pos = pointerPos(currentTouchPosition.x * pointScale, currentTouchPosition.y * pointScale);
				p.dragState.pointerEvent(Input::Pointer::LBUTTON, RELEASED, pos);
				Input::onInputEvent(Input::Event(i, Event::MAP_POINTER, Input::Pointer::LBUTTON, RELEASED, pos.x, pos.y, true, nullptr));
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
