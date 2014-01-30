//
//  GBAROM.h
//  GBA4iOS
//
//  Created by Riley Testut on 8/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GBAEvent;

typedef NS_ENUM(NSInteger, GBAROMType)
{
    GBAROMTypeGBA,
    GBAROMTypeGBC
};

@interface GBAROM : NSObject

@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSString *uniqueName;
@property (readonly, copy, nonatomic) NSString *filepath;
@property (readonly, copy, nonatomic) NSString *saveFileFilepath;
@property (readonly, copy, nonatomic) NSString *rtcFileFilepath;

@property (readonly, assign, nonatomic) GBAROMType type;

@property (readonly, assign, nonatomic) BOOL syncingDisabled;
@property (readonly, assign, nonatomic) BOOL conflicted;

@property (readonly, strong, nonatomic) GBAEvent *event;

+ (GBAROM *)romWithName:(NSString *)name; // Looks in documents directory
+ (GBAROM *)romWithUniqueName:(NSString *)name;
+ (GBAROM *)romWithContentsOfFile:(NSString *)filepath;

- (void)renameToName:(NSString *)name;

+ (BOOL)unzipROMAtPathToROMDirectory:(NSString *)filepath withPreferredROMTitle:(NSString *)name error:(NSError **)error;
+ (BOOL)canAddROMToROMDirectory:(GBAROM *)rom error:(NSError **)error;

@end
