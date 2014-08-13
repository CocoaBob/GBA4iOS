//
//  GBAControllerSkin.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkin.h"
#import "UIScreen+Widescreen.h"
#import "SSZipArchive.h"

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

        NSData *jsonData = [NSData dataWithContentsOfFile:[_filepath stringByAppendingPathComponent:@"info.json"]];
        
        if (jsonData == nil)
        {
            return nil;
        }
        
        _infoDictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] copy];
        
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
    
    if ([controllerSkin imageForOrientation:GBAControllerSkinOrientationPortrait] == nil || [controllerSkin imageForOrientation:GBAControllerSkinOrientationLandscape] == nil)
    {
        NSLog(@"Fixing corrupted default skin...");
        
        NSString *fileType = nil;
        
        switch (skinType)
        {
            case GBAControllerSkinTypeGBA:
                fileType = @"gbaskin";
                break;
                
            case GBAControllerSkinTypeGBC:
                fileType = @"gbcskin";
                break;
        }
        
        
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Default" ofType:fileType];
        [GBAControllerSkin extractSkinAtPathToSkinsDirectory:bundlePath];
        
        controllerSkin = [[GBAControllerSkin alloc] initWithContentsOfFile:filepath];
    }
    
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
        NSLog(@"%@", error);
    }
    
    NSString *destinationPath = [skinTypeDirectory stringByAppendingPathComponent:controllerSkin.identifier];
    
    [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:tempDirectory toPath:destinationPath error:nil];
    
    NSString *infoDictionaryPath = [destinationPath stringByAppendingPathComponent:@"info.json"];
    NSData *jsonData = [NSData dataWithContentsOfFile:infoDictionaryPath];
    NSMutableDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
    
    dictionary[@"type"] = @(skinType);
    jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:nil];
    [jsonData writeToFile:infoDictionaryPath atomically:YES];
    
    if ([contents count] == 0)
    {
        NSLog(@"Not finished yet");
        // Unzipped before it was done copying over
        return NO;
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:[destinationPath stringByAppendingPathComponent:@"__MACOSX"] error:nil];
    
    return YES;
}

- (NSString *)name
{
    NSString *filename = self.infoDictionary[@"name"];
    return filename;
}

- (UIImage *)imageForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[@"assets"];
    
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

- (BOOL)imageExistsForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[@"assets"];
    
    NSString *key = [GBAControllerSkin keyForCurrentDeviceWithDictionary:assets];
    NSString *relativePath = assets[key];
    
    return (relativePath != nil);
}

- (CGRect)rectForButtonRect:(GBAControllerSkinRect)button orientation:(GBAControllerOrientation)orientation
{
    return [self rectForButtonRect:button orientation:orientation extended:YES];
}

- (CGRect)rectForButtonRect:(GBAControllerSkinRect)button orientation:(GBAControllerOrientation)orientation extended:(BOOL)extended
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *layouts = dictionary[@"layouts"];
    
    NSString *deviceKey = [GBAControllerSkin keyForCurrentDeviceWithDictionary:layouts];
    NSDictionary *buttonRects = layouts[deviceKey];
    
    NSString *buttonKey = [self keyForButtonRect:button];
    NSDictionary *buttonRect = buttonRects[buttonKey];
    
    CGRect rect = CGRectMake([buttonRect[@"x"] floatValue], [buttonRect[@"y"] floatValue], [buttonRect[@"width"] floatValue], [buttonRect[@"height"] floatValue]);
    
    // The screen size should be absolute, no extended edges
    if (buttonRect && extended && button != GBAControllerSkinRectScreen)
    {
        NSDictionary *extendedEdges = buttonRects[@"extendedEdges"];
        
        CGFloat topEdge = [extendedEdges[@"left"] floatValue];
        CGFloat bottomEdge = [extendedEdges[@"bottom"] floatValue];
        CGFloat leftEdge = [extendedEdges[@"left"] floatValue];
        CGFloat rightEdge = [extendedEdges[@"right"] floatValue];
        
        // Override master extendedEdges with a specific one for an individual button rect if it exists
        if (buttonRect[@"extendedEdges"])
        {
            NSDictionary *buttonExtendedEdges = buttonRect[@"extendedEdges"];
            
            if (buttonExtendedEdges)
            {
                // Check if non-nil instead of not-zero so 0 can override the general extended edge
                if (buttonExtendedEdges[@"top"])
                {
                    topEdge = [buttonExtendedEdges[@"top"] floatValue];
                }
                
                if (buttonExtendedEdges[@"bottom"])
                {
                    bottomEdge = [buttonExtendedEdges[@"bottom"] floatValue];
                }
                
                if (buttonExtendedEdges[@"left"])
                {
                    leftEdge = [buttonExtendedEdges[@"left"] floatValue];
                }
                
                if (buttonExtendedEdges[@"right"])
                {
                    rightEdge = [buttonExtendedEdges[@"right"] floatValue];
                }
            }
        }
        
        rect.origin.x -= leftEdge;
        rect.origin.y -= topEdge;
        rect.size.width += leftEdge + rightEdge;
        rect.size.height += topEdge + bottomEdge;
    }
        
    return rect;
}

- (NSString *)keyForButtonRect:(GBAControllerSkinRect)button
{
    NSString *key = nil;
    switch (button) {
        case GBAControllerSkinRectDPad:
            key = @"dpad";
            break;
            
        case GBAControllerSkinRectA:
            key = @"a";
            break;
            
        case GBAControllerSkinRectB:
            key = @"b";
            break;
            
        case GBAControllerSkinRectAB:
            key = @"ab";
            break;
            
        case GBAControllerSkinRectStart:
            key = @"start";
            break;
            
        case GBAControllerSkinRectSelect:
            key = @"select";
            break;
            
        case GBAControllerSkinRectL:
            key = @"l";
            break;
            
        case GBAControllerSkinRectR:
            key = @"r";
            break;
            
        case GBAControllerSkinRectMenu:
            key = @"menu";
            break;
            
        case GBAControllerSkinRectScreen:
            key = @"screen";
            break;
    }
    
    return key;
}

- (GBAControllerSkinType)type
{
    return [self.infoDictionary[@"type"] integerValue];
}

- (BOOL)debug
{
    return [self.infoDictionary[@"debug"] boolValue];
}

+ (NSString *)keyForCurrentDeviceWithDictionary:(NSDictionary *)dictionary
{
    NSString *key = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        if ([[UIScreen mainScreen] isWidescreen])
        {
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhoneWidescreen])
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
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPadRetina])
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

+ (BOOL)validObjectExistsInDictionary:(NSDictionary *)dictionary forKey:(NSString *)key
{
    BOOL exists = YES;
    
    id object = [dictionary objectForKey:key];
    
    if ([object isKindOfClass:[NSString class]])
    {
        exists = [(NSString *)object length] > 0;
    }
    else
    {
        exists = (object != nil);
    }
    
    return exists;
}

- (NSDictionary *)dictionaryForOrientation:(GBAControllerOrientation)orientation
{
    NSDictionary *dictionary = nil;
    
    switch (orientation) {
        case GBAControllerSkinOrientationPortrait:
            dictionary = self.infoDictionary[@"portrait"];
            break;
            
        case GBAControllerSkinOrientationLandscape:
            dictionary = self.infoDictionary[@"landscape"];
            break;
    }
    
    return dictionary;
}

- (CGRect)screenRectForOrientation:(GBAControllerOrientation)orientation
{
    return [self rectForButtonRect:GBAControllerSkinRectScreen orientation:orientation extended:YES];
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
    return self.infoDictionary[@"identifier"];
}

@end
