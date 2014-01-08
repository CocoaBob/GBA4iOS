//
//  NSDate+Comparing.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/5/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Comparing)

- (NSInteger)daysSinceDate:(NSDate *)date;
- (NSInteger)daysUntilDate:(NSDate *)date;

@end
