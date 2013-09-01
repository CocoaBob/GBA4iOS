//
//  GBAControllerView.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerView.h"
#import "UIScreen+Widescreen.h"
#import "UITouch+ControllerButtons.h"

@import AudioToolbox;

@interface GBAControllerView () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UIView *overlayView;

@end

@implementation GBAControllerView

#pragma mark - Init

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initialize];
    }
    
    return self;
}

- (void)initialize
{
    self.multipleTouchEnabled = YES;
    self.backgroundColor = [UIColor clearColor];
    
    self.imageView = ({
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self addSubview:imageView];
        imageView;
    });
}

#pragma mark - Getters / Setters

- (void)setController:(GBAController *)controller
{
    _controller = controller;
    
    [self update];
}

- (void)setOrientation:(GBAControllerOrientation)orientation
{
    _orientation = orientation;
    
    [self update];
}

#pragma mark - UIView subclass

- (CGSize)intrinsicContentSize
{
    return self.imageView.image.size;
}

#pragma mark - Touch Handling

static unsigned long pressedButtons;
static unsigned long newtouches[15];
static unsigned long oldtouches[15];

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (touches.count == 3)
    {
        [self.delegate controllerViewDidPressMenuButton:self];
    }
    [self pressButtonsForTouches:touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self updateButtonsForTouches:touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self releaseButtonsForTouches:touches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self releaseButtonsForTouches:touches];
}

#pragma mark Pressing Buttons


- (void)pressButtonsForTouches:(NSSet *)touches
{
    NSMutableSet *set = [NSMutableSet set];
    
    for (UITouch *touch in touches)
    {
        NSSet *pressedButtons = [self buttonsForTouch:touch];
        [set unionSet:pressedButtons];
        
        touch.controllerButtons = pressedButtons;
    }
    
    if (set.count > 0)
    {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"])
        {
            [self vibrate];
        }
    }
    
    // Don't pass on menu button. But we include it in the previous check cause we still want a vibration
    [set removeObject:@(GBAControllerButtonMenu)];
    
    if (set.count > 0)
    {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"])
        {
            [self vibrate];
        }
        
        [self.delegate controllerView:self didPressButtons:set];
    }
}

- (void)updateButtonsForTouches:(NSSet *)touches
{
    NSMutableSet *set = [NSMutableSet set];
    
    // Presses
    for (UITouch *touch in touches)
    {
        NSMutableSet *pressedButtons = [[self buttonsForTouch:touch] mutableCopy];
        NSSet *originalButtons = touch.controllerButtons;
        
        // Forbid sliding into L and R and Menu
        if (!([pressedButtons containsObject:@(GBAControllerButtonL)] || [pressedButtons containsObject:@(GBAControllerButtonR)] || [pressedButtons containsObject:@(GBAControllerButtonMenu)]))
        {
            [pressedButtons minusSet:originalButtons];
            [set unionSet:pressedButtons];
        }
    }
    
    if (set.count > 0)
    {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"])
        {
            [self vibrate];
        }
        
        // Don't pass on menu button
        [set removeObject:@(GBAControllerButtonMenu)];
        
        [self.delegate controllerView:self didPressButtons:set];
    }
    
    [set removeAllObjects];
    
    // Releases
    for (UITouch *touch in touches)
    {
        NSMutableSet *originalButtons = [touch.controllerButtons mutableCopy];
        NSSet *pressedButtons = [self buttonsForTouch:touch];
        
        // So it keeps it pressed down even if your finger shifts off the button into a no-button area. It'll still be released in releaseButtonsForTouches:
        // Also, forbids sliding into L and R and Menu
        if (pressedButtons.count > 0 && !([pressedButtons containsObject:@(GBAControllerButtonL)] || [pressedButtons containsObject:@(GBAControllerButtonR)] || [pressedButtons containsObject:@(GBAControllerButtonMenu)]))
        {
            [originalButtons minusSet:pressedButtons];
            [set unionSet:originalButtons];
            touch.controllerButtons = pressedButtons;
        }
    }
    
    if (set.count > 0)
    {
        // Don't pass on menu button
        [set removeObject:@(GBAControllerButtonMenu)];
        [self.delegate controllerView:self didReleaseButtons:set];
    }
    
}

- (void)releaseButtonsForTouches:(NSSet *)touches
{
    NSMutableSet *set = [NSMutableSet set];
    
    for (UITouch *touch in touches)
    {
        [set unionSet:touch.controllerButtons];
        
        touch.controllerButtons = nil;
    }
    
    if ([set containsObject:@(GBAControllerButtonMenu)])
    {
        [self.delegate controllerViewDidPressMenuButton:self];
        [set removeObject:@(GBAControllerButtonMenu)];
    }

    if (set.count > 0)
    {
        [self.delegate controllerView:self didReleaseButtons:set];
    }
}

void AudioServicesStopSystemSound(int);
void AudioServicesPlaySystemSoundWithVibration(int, id, NSDictionary *);

- (void)vibrate
{
    AudioServicesStopSystemSound(kSystemSoundID_Vibrate);
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSArray *pattern = @[@YES, @30, @NO, @1];
    
    dictionary[@"VibePattern"] = pattern;
    dictionary[@"Intensity"] = @1;
    
    AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
}

- (NSSet *)buttonsForTouch:(UITouch *)touch
{
    NSMutableSet *buttons = [NSMutableSet set];
    
    CGPoint point = [touch locationInView:self];
    
    CGRect dPadRect = [self.controller rectForButtonRect:GBAControllerRectDPad orientation:self.orientation];
    if (CGRectContainsPoint(dPadRect, point))
    {
        CGRect topRect            = CGRectMake(dPadRect.origin.x, dPadRect.origin.y, dPadRect.size.width, dPadRect.size.height * (1.0f/3.0f));
        CGRect bottomRect         = CGRectMake(dPadRect.origin.x, dPadRect.origin.y + dPadRect.size.height * (2.0f/3.0f), dPadRect.size.width, dPadRect.size.height * (1.0f/3.0f));
        CGRect leftRect           = CGRectMake(dPadRect.origin.x, dPadRect.origin.y, dPadRect.size.width * (1.0f/3.0f), dPadRect.size.height);
        CGRect rightRect          = CGRectMake(dPadRect.origin.x + dPadRect.size.width * (2.0f/3.0f), dPadRect.origin.y, dPadRect.size.width * (1.0f/3.0f), dPadRect.size.height);
        
        CGRect topLeftRect        = CGRectIntersection(topRect, leftRect);
        CGRect topRightRect       = CGRectIntersection(topRect, rightRect);
        CGRect bottomLeftRect     = CGRectIntersection(bottomRect, leftRect);
        CGRect bottomRightRect    = CGRectIntersection(bottomRect, rightRect);
        
        if (CGRectContainsPoint(topLeftRect, point))
        {
            [buttons addObject:@(GBAControllerButtonUp)];
            [buttons addObject:@(GBAControllerButtonLeft)];
        }
        else if (CGRectContainsPoint(topRightRect, point))
        {
            [buttons addObject:@(GBAControllerButtonUp)];
            [buttons addObject:@(GBAControllerButtonRight)];
        }
        else if (CGRectContainsPoint(bottomLeftRect, point))
        {
            [buttons addObject:@(GBAControllerButtonDown)];
            [buttons addObject:@(GBAControllerButtonLeft)];
        }
        else if (CGRectContainsPoint(bottomRightRect, point))
        {
            [buttons addObject:@(GBAControllerButtonDown)];
            [buttons addObject:@(GBAControllerButtonRight)];
        }
        else if (CGRectContainsPoint(topRect, point))
        {
            [buttons addObject:@(GBAControllerButtonUp)];
        }
        else if (CGRectContainsPoint(leftRect, point))
        {
            [buttons addObject:@(GBAControllerButtonLeft)];
        }
        else if (CGRectContainsPoint(bottomRect, point))
        {
            [buttons addObject:@(GBAControllerButtonDown)];
        }
        else if (CGRectContainsPoint(rightRect, point))
        {
            [buttons addObject:@(GBAControllerButtonRight)];
        }
        
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectA orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonA)];
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectB orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonB)];
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectAB orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonA)];
        [buttons addObject:@(GBAControllerButtonB)];
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectL orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonL)];
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectR orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonR)];
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectSelect orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonSelect)];
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectStart orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonStart)];
    }
    else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectMenu orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonMenu)];
    }
    
    return buttons;

}


- (void)handleTouchEvent2:(UIEvent *)event forTouchPhase:(UITouchPhase)touchPhase
{
    // Oh man, the hours I spent trying to debug this because I didn't realize t only returns the CHANGED touches, while [event allTouches] actually has all touches
    NSSet *touches = [event allTouches];
    
	int touchstate[15];
    
	int touchcount = [touches count];
	
	for (int i = 0; i < 10; i++)
	{
		touchstate[i] = 0;
		oldtouches[i] = newtouches[i];
	}
    
	for (int i = 0; i < touchcount; i++)
	{
		UITouch *touch = [[touches allObjects] objectAtIndex:i];
		
		if (touch != nil && (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved || touch.phase == UITouchPhaseStationary) )
		{
			CGPoint point = [touch locationInView:self];
            
			touchstate[i] = 1;
            
            
            CGRect dPadRect = [self.controller rectForButtonRect:GBAControllerRectDPad orientation:self.orientation];
            if (CGRectContainsPoint(dPadRect, point))
            {
                CGRect topRect            = CGRectMake(dPadRect.origin.x, dPadRect.origin.y, dPadRect.size.width, dPadRect.size.height * (1.0f/3.0f));
                CGRect bottomRect         = CGRectMake(dPadRect.origin.x, dPadRect.origin.y + dPadRect.size.height * (2.0f/3.0f), dPadRect.size.width, dPadRect.size.height * (1.0f/3.0f));
                CGRect leftRect           = CGRectMake(dPadRect.origin.x, dPadRect.origin.y, dPadRect.size.width * (1.0f/3.0f), dPadRect.size.height);
                CGRect rightRect          = CGRectMake(dPadRect.origin.x + dPadRect.size.width * (2.0f/3.0f), dPadRect.origin.y, dPadRect.size.width * (1.0f/3.0f), dPadRect.size.height);
                
                CGRect topLeftRect        = CGRectIntersection(topRect, leftRect);
                CGRect topRightRect       = CGRectIntersection(topRect, rightRect);
                CGRect bottomLeftRect     = CGRectIntersection(bottomRect, leftRect);
                CGRect bottomRightRect    = CGRectIntersection(bottomRect, rightRect);
                
                if (CGRectContainsPoint(topLeftRect, point))
                {
                    pressedButtons |= GBAControllerButtonUp | GBAControllerButtonLeft;
                    newtouches[i] = GBAControllerButtonUp | GBAControllerButtonLeft;
                }
                else if (CGRectContainsPoint(topRightRect, point))
                {
                    pressedButtons |= GBAControllerButtonUp | GBAControllerButtonRight;
                    newtouches[i] = GBAControllerButtonUp | GBAControllerButtonRight;
                }
                else if (CGRectContainsPoint(bottomLeftRect, point))
                {
                    pressedButtons |= GBAControllerButtonDown | GBAControllerButtonLeft;
                    newtouches[i] = GBAControllerButtonDown | GBAControllerButtonLeft;
                }
                else if (CGRectContainsPoint(bottomRightRect, point))
                {
                    pressedButtons |= GBAControllerButtonDown | GBAControllerButtonRight;
                    newtouches[i] = GBAControllerButtonDown | GBAControllerButtonRight;
                }
                else if (CGRectContainsPoint(topRect, point))
                {
                    pressedButtons |= GBAControllerButtonUp;
                    newtouches[i] = GBAControllerButtonUp;
                }
                else if (CGRectContainsPoint(leftRect, point))
                {
                    pressedButtons |= GBAControllerButtonLeft;
                    newtouches[i] = GBAControllerButtonLeft;
                }
                else if (CGRectContainsPoint(bottomRect, point))
                {
                    pressedButtons |= GBAControllerButtonDown;
                    newtouches[i] = GBAControllerButtonDown;
                }
                else if (CGRectContainsPoint(rightRect, point))
                {
                    pressedButtons |= GBAControllerButtonRight;
                    newtouches[i] = GBAControllerButtonRight;
                }
                
            }
            else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectA orientation:self.orientation], point))
			{
				pressedButtons |= GBAControllerButtonA;
				newtouches[i] = GBAControllerButtonA;
			}
            else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectB orientation:self.orientation], point))
			{
				pressedButtons |= GBAControllerButtonB;
				newtouches[i] = GBAControllerButtonB;
			}
            else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectAB orientation:self.orientation], point))
			{
				pressedButtons |= GBAControllerButtonA | GBAControllerButtonB;
				newtouches[i] = GBAControllerButtonA | GBAControllerButtonB;
			}
			else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectL orientation:self.orientation], point))
			{
				pressedButtons |= GBAControllerButtonL;
				newtouches[i] = GBAControllerButtonL;
			}
			else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectR orientation:self.orientation], point))
			{
				pressedButtons |= GBAControllerButtonR;
				newtouches[i] = GBAControllerButtonR;
			}
			else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectSelect orientation:self.orientation], point))
			{
				pressedButtons |= GBAControllerButtonSelect;
				newtouches[i] = GBAControllerButtonSelect;
			}
			else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectStart orientation:self.orientation], point))
			{
				pressedButtons |= GBAControllerButtonStart;
				newtouches[i] = GBAControllerButtonStart;
			}
			else if (CGRectContainsPoint([self.controller rectForButtonRect:GBAControllerRectMenu orientation:self.orientation], point))
			{
               // [self sendActionsForControlEvents:UIControlEventTouchUpInside];
			}
			
			if(oldtouches[i] != newtouches[i])
			{
				pressedButtons &= ~(oldtouches[i]);
			}
		}
	}
    
    
	for (int i = 0; i < 10; i++)
	{
		if(touchstate[i] == 0)
		{
			pressedButtons &= ~(newtouches[i]);
			newtouches[i] = 0;
			oldtouches[i] = 0;
		}
	}
    
   /* if (self.pressedButtons != pressedButtons)
    {
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"])
        {
            AudioServicesStopSystemSound(kSystemSoundID_Vibrate);
            
            if (touchPhase == UITouchPhaseBegan || touchPhase == UITouchPhaseMoved)
            {
                NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
                NSArray *pattern = @[@YES, @30, @NO, @1];
                
                dictionary[@"VibePattern"] = pattern;
                dictionary[@"Intensity"] = @1;
                
                AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
            }
        }
        
        self.pressedButtons = pressedButtons;
        
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }*/
}

#pragma mark - Public

- (void)showButtonRects
{
    self.overlayView = (
                        {
                            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
                            view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
                            view.userInteractionEnabled = NO;
                            [self addSubview:view];
                            view;
                        });
    
    void(^AddOverlayForButton)(GBAControllerRect button) = ^(GBAControllerRect button)
    {
        UILabel *overlay = [[UILabel alloc] initWithFrame:[self.controller rectForButtonRect:button orientation:self.orientation]];
        overlay.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5];
        overlay.text = [self.controller keyForButtonRect:button];
        overlay.adjustsFontSizeToFitWidth = YES;
        overlay.textColor = [UIColor whiteColor];
        overlay.font = [UIFont boldSystemFontOfSize:18.0f];
        overlay.textAlignment = NSTextAlignmentCenter;
        [self addSubview:overlay];
    };
    
    AddOverlayForButton(GBAControllerRectDPad);
    AddOverlayForButton(GBAControllerRectA);
    AddOverlayForButton(GBAControllerRectB);
    AddOverlayForButton(GBAControllerRectAB);
    AddOverlayForButton(GBAControllerRectL);
    AddOverlayForButton(GBAControllerRectR);
    AddOverlayForButton(GBAControllerRectStart);
    AddOverlayForButton(GBAControllerRectSelect);
    AddOverlayForButton(GBAControllerRectMenu);
    
    // AddOverlayForButton(GBAControllerRectScreen);
}

- (void)hideButtonRects
{
    [self.overlayView removeFromSuperview];
    self.overlayView = nil;
}

#pragma mark - Private

- (void)update
{
    self.imageView.image = [self.controller imageForOrientation:self.orientation];
    [self invalidateIntrinsicContentSize];
}

#pragma mark - Private Helper Methods

@end
