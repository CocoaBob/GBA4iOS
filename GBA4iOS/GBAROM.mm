//
//  GBAROM.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/23/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAROM_Private.h"
#import "FileSHA1Hash.h"

#import "GBAEmulatorCore.h"

#import "SSZipArchive.h"

NSString *const GBAROMConflictedStateChangedNotification = @"GBAROMConflictedStateChangedNotification";
NSString *const GBAROMSyncingDisabledStateChangedNotification = @"GBAROMSyncingDisabledStateChangedNotification";

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
    NSMutableDictionary *cachedROMs = [[NSMutableDictionary alloc] initWithContentsOfFile:[GBAROM cachedROMsPath]];
    
    __block NSString *romFilename = nil;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    [[cachedROMs copy] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *cachedUniqueName, BOOL *stop) {
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
    
    NSString *romFilepath = [tempDirectory stringByAppendingPathComponent:[preferredName stringByAppendingPathExtension:extension]];
    
    if (![preferredName isEqualToString:romFilename])
    {
        // Rename ROM file to preferred name
        [[NSFileManager defaultManager] moveItemAtPath:[tempDirectory stringByAppendingPathComponent:[romFilename stringByAppendingPathExtension:extension]] toPath:romFilepath error:nil];
    }
    
    GBAROM *rom = [GBAROM romWithContentsOfFile:romFilepath];
    
    if (![GBAROM canAddROMToROMDirectory:rom error:error])
    {
        [[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
        
        return NO;
    }
    
    NSString *destinationFilepath = [documentsDirectory stringByAppendingPathComponent:[preferredName stringByAppendingPathExtension:extension]];
    
    [[NSFileManager defaultManager] moveItemAtPath:romFilepath toPath:destinationFilepath error:nil];
    
    [[NSFileManager defaultManager] removeItemAtPath:tempDirectory error:nil];
    
    return YES;
}

+ (BOOL)canAddROMToROMDirectory:(GBAROM *)rom error:(NSError **)error
{
    NSString *uniqueName = rom.uniqueName;
    
    __block NSMutableDictionary *cachedROMs = [NSMutableDictionary dictionaryWithContentsOfFile:[self cachedROMsPath]];
    
    GBAROM *cachedROM = [GBAROM romWithUniqueName:uniqueName];
    
    if (cachedROM && [[NSFileManager defaultManager] fileExistsAtPath:cachedROM.filepath] && ![cachedROM.filepath isEqualToString:rom.filepath])
    {
        *error = [NSError errorWithDomain:@"com.rileytestut.GBA4iOS" code:NSFileWriteFileExistsError userInfo:nil];
        return NO;
    }
    
    // Check if another rom happens to have the same name as this ROM
    GBAROM *sameNameROM = [GBAROM romWithName:rom.name];
    
    if (sameNameROM && ![rom.filepath isEqualToString:sameNameROM.filepath])
    {
        *error = [NSError errorWithDomain:@"com.rileytestut.GBA4iOS" code:NSFileWriteInvalidFileNameError userInfo:nil];
        return NO;
    }

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

#pragma mark - Public

- (void)renameToName:(NSString *)name
{
    NSString *currentName = [self.name copy];
    NSString *currentExtension = [[self.filepath pathExtension] copy];
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    BOOL isConflicted = [self conflicted];
    BOOL isSyncingDisabled = [self syncingDisabled];
    BOOL isNewlyConflicted = [self newlyConflicted];
    
    // Remove the current name from the cached status
    if (isConflicted)
    {
        [self setConflicted:NO];
    }
    
    if (isSyncingDisabled)
    {
        [self setSyncingDisabled:NO];
    }
    
    if (isNewlyConflicted)
    {
        [self setNewlyConflicted:NO];
    }
    
    self.filepath = [documentsDirectory stringByAppendingPathComponent:[name stringByAppendingPathExtension:currentExtension]];
    
    // Set the syncing status back to what it was before the name change
    if (isConflicted)
    {
        [self setConflicted:YES];
    }
    
    if (isSyncingDisabled)
    {
        [self setSyncingDisabled:YES];
    }
    
    if (isNewlyConflicted)
    {
        [self setNewlyConflicted:YES];
    }
    
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

- (NSString *)hexadecimalStringFromData:(NSData *)data {
    
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    
    if (!dataBuffer)
    {
        return @"";
    }
    
    NSUInteger dataLength  = [data length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (NSUInteger i = 0; i < dataLength; ++i)
    {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    
    return [NSString stringWithString:hexString];
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

- (NSString *)rtcFileFilepath
{
    NSString *romDirectory = [self.filepath stringByDeletingLastPathComponent];
    return [romDirectory stringByAppendingPathComponent:[self.name stringByAppendingPathExtension:@"rtc"]];
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

- (BOOL)usesGBCRTC
{
    if (self.type == GBAROMTypeGBA)
    {
        return NO;
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filepath];
    [fileHandle seekToFileOffset:0x147];
    
    NSData *data = [fileHandle readDataOfLength:1];
    
    switch (((unsigned char *)[data bytes])[0])
    {
        case 0x0F:
        case 0x10:
        {
            return true;
        }
            
        default:
        {
           return false;
        }
	}
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
    
    if (!(const char *)[data bytes])
    {
        return @"Unknown";
    }
    
    NSMutableString *embeddedName = [NSMutableString string];
    
    // Safety precaution in case other bytes are picked up from header
    const char *bytes = (const char *)[data bytes];
    for (NSUInteger i = 0; i < (NSUInteger)[data length]; i++)
    {
        unsigned char character = (unsigned char)bytes[i];
        if (character < 128)
        {
            [embeddedName appendFormat:@"%c", character];
        }
    }
    
    // Keep this, I promise it's necessary. Sometimes the converted NSString contains too many characters
    if (embeddedName.length > length)
    {
        DLog(@"Embedded name too long: %@", embeddedName);
        embeddedName = [[embeddedName substringToIndex:length] mutableCopy];
    }
    
    if (embeddedName == nil)
    {
        DLog(@"Error converting embedded name data to string for ROM: %@", self.name);
        return @"Unknown";
    }
    
    [fileHandle closeFile];
    
    // NULL-terminates the string, which we don't want
    //return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return embeddedName;
}

@end
