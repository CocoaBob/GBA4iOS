//
//  GBAROM.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROM_Private.h"
#import "FileSHA1Hash.h"

#if !(TARGET_IPHONE_SIMULATOR)
#import "GBAEmulatorCore.h"
#endif

#import <SSZipArchive/minizip/SSZipArchive.h>

@interface GBAROM ()

@property (readwrite, copy, nonatomic) NSString *filepath;
@property (readwrite, assign, nonatomic) GBAROMType type;

@end

@implementation GBAROM

+ (GBAROM *)romWithContentsOfFile:(NSString *)filepath
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filepath] || !([[[filepath pathExtension] lowercaseString] isEqualToString:@"gb"] || [[[filepath pathExtension] lowercaseString] isEqualToString:@"gbc"] || [[[filepath pathExtension] lowercaseString] isEqualToString:@"gba"]))
    {
        return nil;
    }
    
    GBAROM *rom = [[GBAROM alloc] init];
    rom.filepath = filepath;
    
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

+ (GBAROM *)romWithName:(NSString *)name
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    for (NSString *filename in contents)
    {
        if (!([[[filename pathExtension] lowercaseString] isEqualToString:@"gb"] || [[[filename pathExtension] lowercaseString] isEqualToString:@"gbc"] || [[[filename pathExtension] lowercaseString] isEqualToString:@"gba"]))
        {
            continue;
        }
        
        if ([[filename stringByDeletingPathExtension] isEqualToString:name])
        {
            return [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:filename]];
        }
    }
    
    return nil;
}

+ (GBAROM *)romWithUniqueName:(NSString *)uniqueName
{
    NSMutableDictionary *cachedROMs = [NSMutableDictionary dictionaryWithContentsOfFile:[GBAROM cachedROMsPath]];
    
    __block NSString *romFilename = nil;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [cachedROMs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *cachedUniqueName, BOOL *stop) {
        if ([uniqueName isEqualToString:cachedUniqueName])
        {
            NSString *cachedFilepath = [documentsDirectory stringByAppendingPathComponent:key];
            
            if (![[NSFileManager defaultManager] fileExistsAtPath:cachedFilepath])
            {
                [cachedROMs removeObjectForKey:key];
                [cachedROMs writeToFile:[self cachedROMsPath] atomically:YES];
                return;
            }
            
            romFilename = key;
            *stop = YES;
        }
    }];
    
    if (romFilename == nil)
    {
        return nil;
    }
    
    return [GBAROM romWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:romFilename]];
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
        
        [[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:nil];
        // [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil]; Too many false positives
        
        return NO; // zip file invalid
    }
    
    if (preferredName == nil)
    {
        preferredName = romFilename;
    }
    
    GBAROM *rom = [GBAROM romWithContentsOfFile:[tempDirectory stringByAppendingPathComponent:[romFilename stringByAppendingPathExtension:extension]]];
    NSString *uniqueName = rom.uniqueName;
    
    __block NSMutableDictionary *cachedROMs = [NSMutableDictionary dictionaryWithContentsOfFile:[self cachedROMsPath]];
    
    GBAROM *cachedROM = [GBAROM romWithUniqueName:uniqueName];
    
    if (cachedROM)
    {
        *error = [NSError errorWithDomain:@"com.rileytestut.GBA4iOS" code:NSFileWriteFileExistsError userInfo:nil];
        
        [[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        
        return NO;
    }
    
    // Check if another rom happens to have the same name as this ROM
    
    BOOL romNameIsTaken = (cachedROMs[[rom.filepath lastPathComponent]] != nil);
    
    if (romNameIsTaken)
    {
        *error = [NSError errorWithDomain:@"com.rileytestut.GBA4iOS" code:NSFileWriteInvalidFileNameError userInfo:nil];
        
        [[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        
        return NO;
    }
    
    NSString *originalFilename = [romFilename stringByAppendingPathExtension:extension];
    NSString *destinationFilename = [preferredName stringByAppendingPathExtension:extension];
    
    [[NSFileManager defaultManager] moveItemAtPath:[tempDirectory stringByAppendingPathComponent:originalFilename] toPath:[documentsDirectory stringByAppendingPathComponent:destinationFilename] error:nil];
    
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
    
    return [self.uniqueName isEqualToString:otherROM.uniqueName]; // Use names, not filepaths, to compare
}

- (NSUInteger)hash
{
    return [self.filepath hash];
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

+ (NSString *)cachedROMsPath
{
    NSString *libraryDirectory = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    return [libraryDirectory stringByAppendingPathComponent:@"cachedROMs.plist"];
}

#pragma mark - Getters/Setters

- (NSString *)name
{
    return [[self.filepath lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)saveFileFilepath
{
    NSString *romDirectory = [self.filepath stringByDeletingLastPathComponent];
    return [romDirectory stringByAppendingPathComponent:[self.name stringByAppendingPathExtension:@"sav"]];
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GBAROMSyncingDisabledStateChangedNotification object:self];
    
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GBAROMConflictedStateChangedNotification object:self];
}

- (BOOL)conflicted
{
    NSMutableSet *conflictedROMs = [NSMutableSet setWithArray:[NSArray arrayWithContentsOfFile:[self conflictedROMsPath]]];
    return [conflictedROMs containsObject:self.name];
}

- (BOOL)newlyConflicted
{
    if (![self conflicted])
    {
        [self setNewlyConflicted:NO];
        
        return NO;
    }
    
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

#pragma mark - Unique Name

- (NSString *)uniqueName
{
    NSDictionary *cachedROMs = [[NSDictionary alloc] initWithContentsOfFile:[GBAROM cachedROMsPath]];
    
    NSString *uniqueName = cachedROMs[[self.filepath lastPathComponent]];
    
    if (uniqueName)
    {
        return uniqueName;
    }
    
    NSMutableString *embeddedName = [[self embeddedName] mutableCopy];
    [embeddedName replaceOccurrencesOfString:@"/" withString:@"-" options:0 range:NSMakeRange(0, embeddedName.length)];
    
    CFStringRef fileHash = FileSHA1HashCreateWithPath((__bridge CFStringRef)self.filepath, FileHashDefaultChunkSizeForReadingData);
    
    uniqueName = [[NSString alloc] initWithFormat:@"%@-%@", embeddedName, (__bridge NSString *)fileHash];
    
    CFRelease(fileHash);
    
    if (uniqueName == nil)
    {
#warning remove from final distribution
        [[NSException exceptionWithName:@"ROM Unique Name Nil" reason:@"The unique name cannot be nil" userInfo:@{@"filepath": self.filepath, @"embeddedName": embeddedName}] raise];
    }
    
    return uniqueName;
}

- (NSString *)embeddedName
{
    unsigned long long offset = 0;
    NSUInteger length = 0;
    
    switch (self.type) {
        case GBAROMTypeGBA:
            offset = 0xA0;
            length = 12;
            break;
            
        case GBAROMTypeGBC:
            offset = 0x0134;
            length = 16;
            break;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filepath];
    [fileHandle seekToFileOffset:offset];
    
    NSData *data = [fileHandle readDataOfLength:length];
    
    if (self.type == GBAROMTypeGBC)
    {
        unsigned char buffer[1];
        [data getBytes:buffer range:NSMakeRange(data.length - 1, 1)];
        
        // 0-127 ASCII range. (http://nocash.emubase.de/pandocs.htm#thecartridgeheader )
        if (buffer[0] > 127)
        {
            data = [data subdataWithRange:NSMakeRange(0, data.length - 1)];
        }
    }
    
    if (data == nil)
    {
        DLog(@"Error loading data for ROM, retrying: %@", self.name);
        
        static int attempts = 1;
        
        if (attempts < 3)
        {
            attempts++;
            return [self embeddedName];
        }
        
        return @"";
    }
    
    NSString *embeddedName = [NSString stringWithUTF8String:(const char *)[data bytes]];
    
    // Keep this, I promise it's necessary. Sometimes the converted NSString contains too many characters
    if (embeddedName.length > length)
    {
        DLog(@"Embedded name too long: %@", embeddedName);
        embeddedName = [embeddedName substringToIndex:length];
    }
    
    if (embeddedName == nil)
    {
        DLog(@"Error converting embedded name data to string for ROM: %@", self.name);
        return @"Unknown";
    }
    
    // NULL-terminates the string, which we don't want
    //return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return embeddedName;
}

@end
