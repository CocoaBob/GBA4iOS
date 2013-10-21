//
//  GBAController.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAController.h"
#import "UIScreen+Widescreen.h"
#import <SSZipArchive/minizip/SSZipArchive.h>

@interface GBAController ()

@property (copy, nonatomic) NSDictionary *infoDictionary;

@end

@implementation GBAController

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

+ (GBAController *)controllerWithContentsOfFile:(NSString *)filepath
{
    GBAController *controller = [[GBAController alloc] initWithContentsOfFile:filepath];
    return controller;
}

+ (GBAController *)defaultControllerForSkinType:(GBAControllerSkinType)skinType
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
            
    GBAController *controller = [[GBAController alloc] initWithContentsOfFile:filepath];
    return controller;
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
    
    GBAController *controller = [GBAController controllerWithContentsOfFile:tempDirectory];
    
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
    
    NSString *destinationPath = [skinTypeDirectory stringByAppendingPathComponent:controller.identifier];
        
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
    
    NSString *key = [GBAController keyForCurrentDeviceWithDictionary:assets];
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
    
    NSString *key = [GBAController keyForCurrentDeviceWithDictionary:layout];
    NSDictionary *rect = layout[key];
    
    key = [self keyForButtonRect:button];
    NSDictionary *buttonRect = rect[key];
        
    return CGRectMake([buttonRect[@"X"] floatValue], [buttonRect[@"Y"] floatValue], [buttonRect[@"Width"] floatValue], [buttonRect[@"Height"] floatValue]);
}

- (NSString *)keyForButtonRect:(GBAControllerRect)button
{
    NSString *key = nil;
    switch (button) {
        case GBAControllerRectDPad:
            key = @"D-Pad";
            break;
            
        case GBAControllerRectA:
            key = @"A";
            break;
            
        case GBAControllerRectB:
            key = @"B";
            break;
            
        case GBAControllerRectAB:
            key = @"AB";
            break;
            
        case GBAControllerRectStart:
            key = @"Start";
            break;
            
        case GBAControllerRectSelect:
            key = @"Select";
            break;
            
        case GBAControllerRectL:
            key = @"L";
            break;
            
        case GBAControllerRectR:
            key = @"R";
            break;
            
        case GBAControllerRectMenu:
            key = @"Menu";
            break;
            
        case GBAControllerRectScreen:
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
            if ([dictionary objectForKey:GBAScreenTypeiPhoneWidescreen])
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
            if ([dictionary objectForKey:GBAScreenTypeiPadRetina])
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
        case GBAControllerOrientationPortrait:
            dictionary = self.infoDictionary[@"Portrait"];
            break;
            
        case GBAControllerOrientationLandscape:
            dictionary = self.infoDictionary[@"Landscape"];
            break;
    }
    
    return dictionary;
}

- (CGRect)screenRectForOrientation:(GBAControllerOrientation)orientation
{
    return [self rectForButtonRect:GBAControllerRectScreen orientation:orientation];
}

- (GBAControllerOrientation)supportedOrientations
{
    GBAControllerOrientation supportedOrientations = 0;
    
    if ([self dictionaryForOrientation:GBAControllerOrientationPortrait])
    {
        supportedOrientations |= GBAControllerOrientationPortrait;
    }
    
    if ([self dictionaryForOrientation:GBAControllerOrientationLandscape])
    {
        supportedOrientations |= GBAControllerOrientationLandscape;
    }
        
    return supportedOrientations;
}

- (NSString *)identifier
{
    return self.infoDictionary[@"Identifier"];
}

@end
