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
    return CGSizeMake(320, 240);
}

- (void)setEaglView:(EAGLView *)eaglView
{
    _eaglView = eaglView;
    
    [self addSubview:_eaglView];
}

@end
