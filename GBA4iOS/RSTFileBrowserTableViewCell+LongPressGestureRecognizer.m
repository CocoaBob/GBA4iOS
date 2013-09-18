//
//  RSTFileBrowserTableViewCell+LongPressGestureRecognizer.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/17/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "RSTFileBrowserTableViewCell+LongPressGestureRecognizer.h"

#import <objc/runtime.h>

@implementation RSTFileBrowserTableViewCell (LongPressGestureRecognizer)
@dynamic longPressGestureRecognizer;

- (void)setLongPressGestureRecognizer:(UILongPressGestureRecognizer *)longPressGestureRecognizer
{
    UILongPressGestureRecognizer *previousGestureRecognizer = [self longPressGestureRecognizer];
    
    if (previousGestureRecognizer)
    {
        [self removeGestureRecognizer:previousGestureRecognizer];
    }
    
    [self addGestureRecognizer:longPressGestureRecognizer];
    
    objc_setAssociatedObject(self, @selector(longPressGestureRecognizer), longPressGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UILongPressGestureRecognizer *)longPressGestureRecognizer
{
    return objc_getAssociatedObject(self, @selector(longPressGestureRecognizer));
}

@end
