//
//  GBAEmulatorScreen.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAEmulatorScreen.h"

@implementation GBAEmulatorScreen

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
    }
    
    return self;
}

- (CGSize)intrinsicContentSize
{    
    return self.eaglView.bounds.size;
}

- (void)setEaglView:(UIView *)eaglView
{
#if !(TARGET_IPHONE_SIMULATOR)
    _eaglView = (EAGLView *)eaglView;
#else
    _eaglView = eaglView;
#endif
    
    [self addSubview:_eaglView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.eaglView.center = CGPointMake(roundf(self.bounds.size.width/2.0f), roundf(self.bounds.size.height/2.0f));
    self.eaglView.frame = CGRectIntegral(self.eaglView.frame);
}

@end
