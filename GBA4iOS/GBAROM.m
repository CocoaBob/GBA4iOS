//
//  GBAROM.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROM.h"

@interface GBAROM ()

@property (readwrite, copy, nonatomic) NSString *name;
@property (readwrite, copy, nonatomic) NSString *filepath;

@end

@implementation GBAROM

+ (GBAROM *)romWithContentsOfFile:(NSString *)filepath
{
    GBAROM *rom = [[GBAROM alloc] init];
    rom.filepath = filepath;
    rom.name = [[filepath lastPathComponent] stringByDeletingPathExtension];
    
    return rom;
}

@end
