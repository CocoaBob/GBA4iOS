//
//  NSURLSessionTask+UniqueTaskIdentifier.m
//
//  Created by Riley Testut on 7/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "NSURLSessionTask+UniqueTaskIdentifier.h"

#import <objc/runtime.h>

@implementation NSObject (UniqueTaskIdentifier)
@dynamic uniqueTaskIdentifier;

- (void)setUniqueTaskIdentifier:(NSString *)uniqueTaskIdentifier
{
    objc_setAssociatedObject(self, @selector(uniqueTaskIdentifier), uniqueTaskIdentifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)uniqueTaskIdentifier
{
    return objc_getAssociatedObject(self, @selector(uniqueTaskIdentifier));
}

@end
