//
//  GBAROM.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROM.h"

#import <SSZipArchive/minizip/SSZipArchive.h>

NSString *const GBAROMConflictedStateChanged = @"GBAROMConflictedStateChanged";
NSString *const GBAROMSyncingDisabledStateChanged = @"GBAROMSyncingDisabledStateChanged";

@interface GBAROM ()

@property (readwrite, copy, nonatomic) NSString *filepath;
@property (readwrite, assign, nonatomic) GBAROMType type;

@end

@implementation GBAROM

+ (GBAROM *)romWithContentsOfFile:(NSString *)filepath
{
    GBAROM *rom = [[GBAROM alloc] init];
    rom.filepath = filepath;
    
    // We sometimes create dummy GBAROMs to pass to methods, so DON'T verify that the filepath is valid
    
    if ([[[filepath pathExtension] lowercaseString] isEqualToString:@"gb"] || [[[filepath pathExtension] lowercaseString] isEqualToString:@"gbc"])
    {
        rom.type = GBAROMTypeGBC;
    }
    else
    {
        rom.type = GBAROMTypeGBA;
    }
    
    return rom;
}

+ (BOOL)unzipROMAtPathToROMDirectory:(NSString *)filepath withPreferredROMTitle:(NSString *)preferredName error:(NSError **)error
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
    
    if (romFilename == nil)
    {
        *error = [NSError errorWithDomain:@"com.rileytestut.GBA4iOS" code:NSFileReadNoSuchFileError userInfo:nil];
        return NO; // zip file invalid
    }
    
    if (preferredName == nil)
    {
        preferredName = romFilename;
    }
    
    contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    BOOL fileExists = NO;
    
    for (NSString *filename in contents)
    {
        // Don't check for .zip extension, cause we're in the process of unzipping
        if ([[[filename pathExtension] lowercaseString] isEqualToString:@"gba"] || [[[filename pathExtension] lowercaseString] isEqualToString:@"gbc"] ||
            [[[filename pathExtension] lowercaseString] isEqualToString:@"gb"] /* || [[[filename pathExtension] lowercaseString] isEqualToString:@"zip"]*/)
        {
            NSString *name = [filename stringByDeletingPathExtension];
            
            if ([name isEqualToString:preferredName])
            {
                fileExists = YES;
                break;
            }
        }
    }
    
    if (fileExists)
    {
        *error = [NSError errorWithDomain:@"com.rileytestut.GBA4iOS" code:NSFileWriteFileExistsError userInfo:nil];
        return NO;
    }
    else
    {
        NSString *originalFilename = [romFilename stringByAppendingPathExtension:extension];
        NSString *destinationFilename = [preferredName stringByAppendingPathExtension:extension];
        
        [[NSFileManager defaultManager] moveItemAtPath:[tempDirectory stringByAppendingPathComponent:originalFilename] toPath:[documentsDirectory stringByAppendingPathComponent:destinationFilename] error:nil];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:nil];
    
    return YES;
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

#pragma mark - Getters/Setters

- (NSString *)name
{
    return [[self.filepath lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)saveFileFilepath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    return [documentsDirectory stringByAppendingPathComponent:[self.name stringByAppendingPathExtension:@"sav"]];
}

- (void)setSyncingDisabled:(BOOL)syncingDisabled
{
    NSMutableSet *syncingDisabledROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]];
    
    if (syncingDisabledROMs == nil)
    {
        syncingDisabledROMs = [NSMutableSet set];
    }
    
    if (syncingDisabled)
    {
        [syncingDisabledROMs addObject:self.name];
    }
    else
    {
        [syncingDisabledROMs removeObject:self.name];
    }
    
    [[syncingDisabledROMs allObjects] writeToFile:[self syncingDisabledROMsPath] atomically:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GBAROMSyncingDisabledStateChanged object:self];
    
}

- (BOOL)syncingDisabled
{
    NSMutableSet *disabledROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self syncingDisabledROMsPath]]];
    return [disabledROMs containsObject:self.name];
}

- (void)setConflicted:(BOOL)conflicted
{
    NSMutableSet *conflictedROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
    
    if (conflictedROMs == nil)
    {
        conflictedROMs = [NSMutableSet set];
    }
    
    BOOL previouslyConflicted = [conflictedROMs containsObject:self.name];
    
    if (previouslyConflicted == conflicted)
    {
        return;
    }
    
    if (conflicted)
    {
        [conflictedROMs addObject:self.name];
        [self setNewlyConflicted:YES];
    }
    else
    {
        [conflictedROMs removeObject:self.name];
        [self setNewlyConflicted:NO];
    }
    
    [[conflictedROMs allObjects] writeToFile:[self conflictedROMsPath] atomically:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GBAROMConflictedStateChanged object:self];
}

- (BOOL)conflicted
{
    NSMutableSet *conflictedROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
    return [conflictedROMs containsObject:self.name];
}

- (BOOL)newlyConflicted
{
    NSSet *newlyConflictedROMs = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"newlyConflictedROMs"]];
    
    return [newlyConflictedROMs containsObject:self.name];
}

- (void)setNewlyConflicted:(BOOL)newlyConflicted
{
    NSMutableSet *newlyConflictedROMs = [NSMutableSet setWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"newlyConflictedROMs"]];
    
    if (newlyConflictedROMs == nil)
    {
        newlyConflictedROMs = [NSMutableSet set];
    }
    
    if (newlyConflicted)
    {
        [newlyConflictedROMs addObject:self.name];
    }
    else
    {
        [newlyConflictedROMs removeObject:self.name];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:[newlyConflictedROMs allObjects] forKey:@"newlyConflictedROMs"];
}

#pragma mark - Helper Methods

- (NSString *)dropboxSyncDirectoryPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString *dropboxDirectory = [libraryDirectory stringByAppendingPathComponent:@"Dropbox Sync"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:dropboxDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    return dropboxDirectory;
}

- (NSString *)conflictedROMsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"conflictedROMs.plist"];
}

- (NSString *)syncingDisabledROMsPath
{
    return [[self dropboxSyncDirectoryPath] stringByAppendingPathComponent:@"syncingDisabledROMs.plist"];
}


@end
