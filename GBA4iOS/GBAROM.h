//
//  GBAROM.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GBAROM : NSObject

@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSString *filepath;
@property (readonly, strong, nonatomic) NSString *romCode;

+ (GBAROM *)romWithContentsOfFile:(NSString *)filepath;

@end
