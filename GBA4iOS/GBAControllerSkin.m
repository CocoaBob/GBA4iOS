//
//  GBAControllerSkin.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkin.h"
#import "UIScreen+Widescreen.h"
#import <SSZipArchive.h>

@interface GBAControllerSkin ()

@property (copy, nonatomic) NSDictionary *infoDictionary;

@end

@implementation GBAControllerSkin

- (instancetype)initWithContentsOfFile:(NSString *)filepath
{
    self = [super init];
    if (self)
    {
        _filepath = [filepath copy];
        _infoDictionary = [[NSDictionary dictionaryWithContentsOfFile:[_filepath stringByAppendingPathComponent:@"Info.plist"]] copy];
        
        if (_infoDictionary == nil)
        {
            return nil;
        }
    }
    
    return self;
}

+ (GBAControllerSkin *)controllerSkinWithContentsOfFile:(NSString *)filepath
{
    GBAControllerSkin *controllerSkin = [[GBAControllerSkin alloc] initWithContentsOfFile:filepath];
    return controllerSkin;
}

+ (GBAControllerSkin *)defaultControllerSkinForSkinType:(GBAControllerSkinType)skinType
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *skinsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Skins"];
    
    NSString *filepath = nil;
    
    switch (skinType)
    {
        case GBAControllerSkinTypeGBA:
            filepath = [skinsDirectory stringByAppendingPathComponent:[@"GBA/" stringByAppendingString:GBADefaultSkinIdentifier]];
            break;
            
        case GBAControllerSkinTypeGBC:
            filepath = [skinsDirectory stringByAppendingPathComponent:[@"GBC/" stringByAppendingString:GBADefaultSkinIdentifier]];
            break;
    }
            
    GBAControllerSkin *controllerSkin = [[GBAControllerSkin alloc] initWithContentsOfFile:filepath];
    return controllerSkin;
}

+ (GBAControllerSkin *)invisibleSkin
{
    // Don't use designated initializer, as that will return nil
    GBAControllerSkin *controllerSkin = [[GBAControllerSkin alloc] init];
    return controllerSkin;
}

+ (BOOL)extractSkinAtPathToSkinsDirectory:(NSString *)filepath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    
    NSString *name = [[filepath lastPathComponent] stringByDeletingPathExtension];
    NSString *tempDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    [SSZipArchive unzipFileAtPath:filepath toDestination:tempDirectory];
    
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempDirectory error:nil];
    
    GBAControllerSkin *controllerSkin = [GBAControllerSkin controllerSkinWithContentsOfFile:tempDirectory];
    
    NSString *skinsDirectory = [documentsDirectory stringByAppendingPathComponent:@"Skins"];
    NSString *skinTypeDirectory = nil;
    GBAControllerSkinType skinType = GBAControllerSkinTypeGBA;
    
    if ([[[filepath pathExtension] lowercaseString] isEqualToString:@"gbcskin"])
    {
        skinTypeDirectory = [skinsDirectory stringByAppendingPathComponent:@"GBC"];
        skinType = GBAControllerSkinTypeGBC;
    }
    else
    {
        skinTypeDirectory = [skinsDirectory stringByAppendingPathComponent:@"GBA"];
        skinType = GBAControllerSkinTypeGBA;
    }
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:skinTypeDirectory withIntermediateDirectories:YES attributes:nil error:&error])
    {
        ELog(error);
    }
    
    NSString *destinationPath = [skinTypeDirectory stringByAppendingPathComponent:controllerSkin.identifier];
        
    [[NSFileManager defaultManager] moveItemAtPath:tempDirectory toPath:destinationPath error:nil];
    
#warning may eventually change filename away from Info.plist
    
    NSString *infoDictionaryPath = [destinationPath stringByAppendingPathComponent:@"Info.plist"];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithContentsOfFile:infoDictionaryPath];
    
    dictionary[@"type"] = @(skinType);
    [dictionary writeToFile:infoDictionaryPath atomically:YES];
    
    if ([contents count] == 0)
    {
        DLog(@"Not finished yet");
        // Unzipped before it was done copying over
        return NO;
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:[destinationPath stringByAppendingPathComponent:@"__MACOSX"] error:nil];
    
    return YES;
}

- (NSString *)name
{
    NSString *filename = self.infoDictionary[@"Name"];
    return filename;
}

- (UIImage *)imageForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[@"Assets"];
    
    NSString *key = [GBAControllerSkin keyForCurrentDeviceWithDictionary:assets];
    NSString *relativePath = assets[key];
    
    NSString *filepath = [self.filepath stringByAppendingPathComponent:relativePath];
        
    CGFloat scale = [[UIScreen mainScreen] scale];
    
    if ([key isEqualToString:GBAScreenTypeiPad])
    {
        scale = 1.0f; // In case of a skin without retina artwork
    }
    
    UIImage *image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfFile:filepath] scale:scale];
    
    return image;
}

- (CGRect)rectForButtonRect:(GBAControllerRect)button orientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *layout = dictionary[@"Layout"];
    
    NSString *key = [GBAControllerSkin keyForCurrentDeviceWithDictionary:layout];
    NSDictionary *rect = layout[key];
    
    key = [self keyForButtonRect:button];
    NSDictionary *buttonRect = rect[key];
        
    return CGRectMake([buttonRect[@"X"] floatValue], [buttonRect[@"Y"] floatValue], [buttonRect[@"Width"] floatValue], [buttonRect[@"Height"] floatValue]);
}

- (NSString *)keyForButtonRect:(GBAControllerRect)button
{
    NSString *key = nil;
    switch (button) {
        case GBAControllerSkinRectDPad:
            key = @"D-Pad";
            break;
            
        case GBAControllerSkinRectA:
            key = @"A";
            break;
            
        case GBAControllerSkinRectB:
            key = @"B";
            break;
            
        case GBAControllerSkinRectAB:
            key = @"AB";
            break;
            
        case GBAControllerSkinRectStart:
            key = @"Start";
            break;
            
        case GBAControllerSkinRectSelect:
            key = @"Select";
            break;
            
        case GBAControllerSkinRectL:
            key = @"L";
            break;
            
        case GBAControllerSkinRectR:
            key = @"R";
            break;
            
        case GBAControllerSkinRectMenu:
            key = @"Menu";
            break;
            
        case GBAControllerSkinRectScreen:
            key = @"Screen";
            break;
    }
    
    return key;
}

- (GBAControllerSkinType)type
{
    return [self.infoDictionary[@"type"] integerValue];
}

+ (NSString *)keyForCurrentDeviceWithDictionary:(NSDictionary *)dictionary
{
    NSString *key = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        if ([[UIScreen mainScreen] isWidescreen])
        {
            if ([[dictionary objectForKey:GBAScreenTypeiPhoneWidescreen] length] > 0)
            {
                key = GBAScreenTypeiPhoneWidescreen;
            }
            else
            {
                key = GBAScreenTypeiPhone;
            }
        }
        else
        {
            key = GBAScreenTypeiPhone;
        }
        
    }
    else
    {
        if ([[UIScreen mainScreen] scale] == 2.0)
        {
            if ([[dictionary objectForKey:GBAScreenTypeiPadRetina] length] > 0)
            {
                key = GBAScreenTypeiPadRetina;
            }
            else
            {
                key = GBAScreenTypeiPad;
            }
        }
        else
        {
            key = GBAScreenTypeiPad;
        }
    }
    
    return key;
}

- (NSDictionary *)dictionaryForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = nil;
    
    switch (orientation) {
        case GBAControllerSkinOrientationPortrait:
            dictionary = self.infoDictionary[@"Portrait"];
            break;
            
        case GBAControllerSkinOrientationLandscape:
            dictionary = self.infoDictionary[@"Landscape"];
            break;
    }
    
    return dictionary;
}

- (CGRect)screenRectForOrientation:(GBAControllerOrientation)orientation
{
    return [self rectForButtonRect:GBAControllerSkinRectScreen orientation:orientation];
}

- (GBAControllerOrientation)supportedOrientations
{
    GBAControllerOrientation supportedOrientations = 0;
    
    if ([self dictionaryForOrientation:GBAControllerSkinOrientationPortrait])
    {
        supportedOrientations |= GBAControllerSkinOrientationPortrait;
    }
    
    if ([self dictionaryForOrientation:GBAControllerSkinOrientationLandscape])
    {
        supportedOrientations |= GBAControllerSkinOrientationLandscape;
    }
        
    return supportedOrientations;
}

- (NSString *)identifier
{
    return self.infoDictionary[@"Identifier"];
}

@end
