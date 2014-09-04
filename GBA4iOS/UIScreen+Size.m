//
//  UIScreen+Size.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "UIScreen+Size.h"

@implementation UIScreen (Size)

- (BOOL)isWidescreen
{
    return [self bounds].size.height > 480 || [self bounds].size.width > 480;
}

- (BOOL)is4inches
{
    return [self bounds].size.height == 568 || [self bounds].size.width == 568;
}

- (BOOL)is4_7inches
{
    return [self bounds].size.height == 667 || [self bounds].size.width == 667;
}

- (BOOL)is5_5inches
{
    return [self bounds].size.height == 736 || [self bounds].size.width == 736;
}

@end
