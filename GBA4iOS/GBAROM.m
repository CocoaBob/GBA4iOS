//
//  GBAROM.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROM.h"

#import <SSZipArchive/minizip/SSZipArchive.h>

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

+ (void)unzipROMAtPathToROMDirectory:(NSString *)filepath withPreferredROMTitle:(NSString *)preferredName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *name = [[filepath lastPathComponent] stringByDeletingPathExtension];
    NSString *tempDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    [SSZipArchive unzipFileAtPath:filepath toDestination:tempDirectory];

    NSString *romFilename = nil;
    NSString *extension = nil;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        if ([[[filename pathExtension] lowercaseString] isEqualToString:@"gba"] || [[[filename pathExtension] lowercaseString] isEqualToString:@"gbc"] ||
            [[[filename pathExtension] lowercaseString] isEqualToString:@"gb"])
        {
            romFilename = [filename stringByDeletingPathExtension];
            extension = [filename pathExtension];
            break;
        }
    }
    
    if (preferredName == nil)
    {
        preferredName = romFilename;
    }
    
    NSString *destinationFilename = [preferredName stringByAppendingPathExtension:extension];
    
    DLog(@"Destination: %@", destinationFilename);
    
    [[NSFileManager defaultManager] moveItemAtPath:[tempDirectory stringByAppendingPathComponent:romFilename] toPath:[documentsDirectory stringByAppendingPathComponent:destinationFilename] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:nil];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GBAROM class]])
    {
        return NO;
    }
    
    GBAROM *otherROM = (GBAROM *)object;
    
    return [self.filepath isEqualToString:otherROM.filepath];
}

- (NSUInteger)hash
{
    return [self.filepath hash];
}

@end
