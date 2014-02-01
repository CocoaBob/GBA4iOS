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
#import "UIDevice-Hardware.h"

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

- (void)setControllerSkin:(GBAControllerSkin *)controller
{
    _controllerSkin = controller;
    
    [self update];
}

- (void)setOrientation:(GBAControllerOrientation)orientation
{
    _orientation = orientation;
    
    [self update];
}

- (void)setSkinOpacity:(CGFloat)skinOpacity
{
    _skinOpacity = skinOpacity;
    
    self.imageView.alpha = skinOpacity;
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
    }
    
    [self.delegate controllerInput:self didPressButtons:set];
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
        
        [self.delegate controllerInput:self didPressButtons:set];
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
        [self.delegate controllerInput:self didReleaseButtons:set];
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
        [self.delegate controllerInputDidPressMenuButton:self];
        [set removeObject:@(GBAControllerButtonMenu)];
    }

    if (set.count > 0)
    {
        [self.delegate controllerInput:self didReleaseButtons:set];
    }
}

void AudioServicesStopSystemSound(int);
void AudioServicesPlaySystemSoundWithVibration(int, id, NSDictionary *);

- (void)vibrate
{
    AudioServicesStopSystemSound(kSystemSoundID_Vibrate);
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSArray *pattern = @[@YES, @30, @NO, @1];
    
    if ([[UIDevice currentDevice] platformType] == UIDevice5SiPhone)
    {
        // iPhone 5S has a weaker vibration motor, so we vibrate for 10ms longer to compensate
        pattern = @[@YES, @40, @NO, @1];
    }
    
    dictionary[@"VibePattern"] = pattern;
    dictionary[@"Intensity"] = @1;
    
    AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
}

- (NSSet *)buttonsForTouch:(UITouch *)touch
{
    NSMutableSet *buttons = [NSMutableSet set];
    
    CGPoint point = [touch locationInView:self.imageView]; // In case, for example, a widescreen iPhone is using a skin that doesn't support the 4" screen
    
    CGRect extendedDPadRect = [self.controllerSkin rectForButtonRect:GBAControllerSkinRectDPad orientation:self.orientation extended:YES];
    if (CGRectContainsPoint(extendedDPadRect, point))
    {
        CGRect dPadRect = [self.controllerSkin rectForButtonRect:GBAControllerSkinRectDPad orientation:self.orientation extended:NO];
        
        CGFloat extendedTop       = CGRectGetMinY(dPadRect) - CGRectGetMinY(extendedDPadRect);
        CGFloat extendedBottom    = CGRectGetMaxY(extendedDPadRect) - CGRectGetMaxY(dPadRect);
        CGFloat extendedLeft      = CGRectGetMinX(dPadRect) - CGRectGetMinX(extendedDPadRect);
        CGFloat extendedRight     = CGRectGetMaxX(extendedDPadRect) - CGRectGetMaxX(dPadRect);
                
        CGRect topRect            = CGRectMake(dPadRect.origin.x - extendedLeft,
                                               dPadRect.origin.y - extendedTop,
                                               dPadRect.size.width + extendedLeft + extendedRight,
                                               dPadRect.size.height * (1.0f/3.0f) + extendedTop);
        
        CGRect bottomRect         = CGRectMake(dPadRect.origin.x - extendedLeft,
                                               dPadRect.origin.y + dPadRect.size.height * (2.0f/3.0f),
                                               dPadRect.size.width + extendedLeft + extendedRight,
                                               dPadRect.size.height * (1.0f/3.0f) + extendedBottom);
        
        CGRect leftRect           = CGRectMake(dPadRect.origin.x - extendedLeft,
                                               dPadRect.origin.y - extendedTop,
                                               dPadRect.size.width * (1.0f/3.0f) + extendedLeft,
                                               dPadRect.size.height + extendedTop + extendedBottom);
        
        CGRect rightRect          = CGRectMake(dPadRect.origin.x + dPadRect.size.width * (2.0f/3.0f),
                                               dPadRect.origin.y - extendedTop,
                                               dPadRect.size.width * (1.0f/3.0f) + extendedRight,
                                               dPadRect.size.height + extendedTop + extendedBottom);
        
        CGRect topLeftRect        = CGRectIntersection(topRect, leftRect);
        CGRect topRightRect       = CGRectIntersection(topRect, rightRect);
        CGRect bottomLeftRect     = CGRectIntersection(bottomRect, leftRect);
        CGRect bottomRightRect    = CGRectIntersection(bottomRect, rightRect);
        
        // Below used for visual debugging of dPad layout
        /*
        UIView *view1 = [[UIView alloc] initWithFrame:topRect];
        view1.backgroundColor = [UIColor blueColor];
        view1.alpha = 0.5;
        
        UIView *view2 = [[UIView alloc] initWithFrame:bottomRect];
        view2.backgroundColor = [UIColor greenColor];
        view2.alpha = 0.5;
        
        UIView *view3 = [[UIView alloc] initWithFrame:leftRect];
        view3.backgroundColor = [UIColor purpleColor];
        view3.alpha = 0.5;
        
        UIView *view4 = [[UIView alloc] initWithFrame:rightRect];
        view4.backgroundColor = [UIColor yellowColor];
        view4.alpha = 0.5;
        
        [self addSubview:view1];
        [self addSubview:view2];
        [self addSubview:view3];
        [self addSubview:view4];
         */
        
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
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectA orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonA)];
    }
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectB orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonB)];
    }
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectAB orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonA)];
        [buttons addObject:@(GBAControllerButtonB)];
    }
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectL orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonL)];
    }
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectR orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonR)];
    }
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectSelect orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonSelect)];
    }
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectStart orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonStart)];
    }
    else if (CGRectContainsPoint([self.controllerSkin rectForButtonRect:GBAControllerSkinRectMenu orientation:self.orientation], point))
    {
        [buttons addObject:@(GBAControllerButtonMenu)];
    }
    
    return buttons;

}

#pragma mark - Public

- (void)showButtonRects
{
    [self.overlayView removeFromSuperview];
    
    self.overlayView = (
                        {
                            UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height)];
                            view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
                            view.userInteractionEnabled = NO;
                            [self addSubview:view];
                            view;
                        });
    
    void(^AddOverlayForButton)(GBAControllerSkinRect button) = ^(GBAControllerSkinRect button)
    {
        UILabel *overlay = [[UILabel alloc] initWithFrame:[self.controllerSkin rectForButtonRect:button orientation:self.orientation]];
                
        overlay.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5];
        overlay.text = [self.controllerSkin keyForButtonRect:button];
        overlay.adjustsFontSizeToFitWidth = YES;
        overlay.minimumScaleFactor = 0.01;
        overlay.textColor = [UIColor whiteColor];
        overlay.font = [UIFont boldSystemFontOfSize:18.0f];
        overlay.textAlignment = NSTextAlignmentCenter;
        [self.overlayView addSubview:overlay];
    };
    
    AddOverlayForButton(GBAControllerSkinRectDPad);
    AddOverlayForButton(GBAControllerSkinRectA);
    AddOverlayForButton(GBAControllerSkinRectB);
    AddOverlayForButton(GBAControllerSkinRectAB);
    AddOverlayForButton(GBAControllerSkinRectL);
    AddOverlayForButton(GBAControllerSkinRectR);
    AddOverlayForButton(GBAControllerSkinRectStart);
    AddOverlayForButton(GBAControllerSkinRectSelect);
    AddOverlayForButton(GBAControllerSkinRectMenu);
    
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
    self.imageView.image = [self.controllerSkin imageForOrientation:self.orientation];
    [self invalidateIntrinsicContentSize];
}

#pragma mark - Private Helper Methods

@end
