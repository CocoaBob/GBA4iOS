//
//  GBAControllerSkin.m
//  GBA4iOS
//
//  Created by Riley Testut on 8/31/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkin_Private.h"
#import "UIScreen+Size.h"
#import "SSZipArchive.h"
#import "UIImage+PDF.h"

@import MobileCoreServices;

NSString *const GBADefaultSkinIdentifier = @"com.GBA4iOS.default";

NSString *const GBAScreenTypeiPhone = @"iPhone";
NSString *const GBAScreenTypeiPhoneWidescreen = @"iPhone Widescreen";
NSString *const GBAScreenTypeiPhone4_0 = @"iPhone 4\"";
NSString *const GBAScreenTypeiPhone4_7 = @"iPhone 4.7\"";
NSString *const GBAScreenTypeiPhone5_5 = @"iPhone 5.5\"";
NSString *const GBAScreenTypeiPad = @"iPad";
NSString *const GBAScreenTypeiPadRetina = @"iPad Retina";
NSString *const GBAScreenTypeResizableiPhone = @"Resizable iPhone";
NSString *const GBAScreenTypeResizableiPad = @"Resizable iPad";

NSString *const GBAControllerSkinNameKey = @"name";
NSString *const GBAControllerSkinIdentifierKey = @"identifier";
NSString *const GBAControllerSkinTypeKey = @"type";
NSString *const GBAControllerSkinResizableKey = @"resizable";
NSString *const GBAControllerSkinDebugKey = @"debug";
NSString *const GBAControllerSkinOrientationPortraitKey = @"portrait";
NSString *const GBAControllerSkinOrientationLandscapeKey = @"landscape";
NSString *const GBAControllerSkinAssetsKey = @"assets";
NSString *const GBAControllerSkinLayoutsKey = @"layouts";
NSString *const GBAControllerSkinDesignerKey = @"designer";
NSString *const GBAControllerSkinURLKey = @"url";

NSString *const GBAControllerSkinLayoutXKey = @"x";
NSString *const GBAControllerSkinLayoutYKey = @"y";
NSString *const GBAControllerSkinLayoutWidthKey = @"width";
NSString *const GBAControllerSkinLayoutHeightKey = @"height";

NSString *const GBAControllerSkinExtendedEdgesKey = @"extendedEdges";
NSString *const GBAControllerSkinExtendedEdgesTopKey = @"top";
NSString *const GBAControllerSkinExtendedEdgesBottomKey = @"bottom";
NSString *const GBAControllerSkinExtendedEdgesLeftKey = @"left";
NSString *const GBAControllerSkinExtendedEdgesRightKey = @"right";

NSString *const GBAControllerSkinMappingSizeKey = @"mappingSize";
NSString *const GBAControllerSkinMappingSizeWidthKey = @"width";
NSString *const GBAControllerSkinMappingSizeHeightKey = @"height";

@interface GBAControllerSkin ()

@property (readwrite, copy, nonatomic) NSString *filepath;
@property (readwrite, copy, nonatomic) NSString *filename;

@property (copy, nonatomic) NSDictionary *infoDictionary;
@property (strong, nonatomic) UIImage *portraitImage;
@property (strong, nonatomic) UIImage *landscapeImage;

@end

@implementation GBAControllerSkin

- (instancetype)initWithContentsOfFile:(NSString *)filepath
{
    NSData *jsonData = [NSData dataWithContentsOfFile:[filepath stringByAppendingPathComponent:@"info.json"]];
    
    if (jsonData == nil)
    {
        return nil;
    }
    
    NSDictionary *dictionary = [[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] copy];
    
    if (dictionary == nil)
    {
        return nil;
    }
    
    self = [self initWithDictionary:dictionary];
    if (self)
    {
        _filepath = [filepath copy];
        _filename = [[_filename lastPathComponent] copy];
    }
    
    return self;
}

- (instancetype)initWithRemoteDictionary:(NSDictionary *)dictionary
{
    self = [self initWithDictionary:dictionary];
    if (self)
    {
        NSString *filename = @"skin";
        NSString *pathExtension = nil;
        
        if (self.type == GBAControllerSkinTypeGBA)
        {
            pathExtension = @"gbaskin";
        }
        else
        {
            pathExtension = @"gbcskin";
        }
        
        _filename = [filename stringByAppendingPathExtension:pathExtension];
    }
    
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self)
    {
        _infoDictionary = [dictionary copy];
    }
    
    return self;
}

#pragma mark - NSCoding -

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *filepath = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(filepath))];
    NSString *filename = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(filename))];
    NSDictionary *infoDictionary = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(infoDictionary))];
    
    self = [self initWithDictionary:infoDictionary];
    self.filepath = filepath;
    self.filename = filename;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.filepath forKey:NSStringFromSelector(@selector(filepath))];
    [aCoder encodeObject:self.filename forKey:NSStringFromSelector(@selector(filename))];
    [aCoder encodeObject:self.infoDictionary forKey:NSStringFromSelector(@selector(infoDictionary))];
}

#pragma mark - Convenience Initializers -

+ (instancetype)controllerSkinWithContentsOfFile:(NSString *)filepath
{
    GBAControllerSkin *controllerSkin = [[GBAControllerSkin alloc] initWithContentsOfFile:filepath];
    return controllerSkin;
}

+ (instancetype)controllerSkinWithDictionary:(NSDictionary *)dictionary
{
    GBAControllerSkin *controllerSkin = [[GBAControllerSkin alloc] initWithDictionary:dictionary];
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

#pragma mark - Extracting -

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
    
    dictionary[GBAControllerSkinTypeKey] = @(skinType);
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

#pragma mark - Retrieve Public Properties -

- (NSString *)name
{
    NSString *filename = self.infoDictionary[GBAControllerSkinNameKey];
    return filename;
}

- (NSString *)identifier
{
    return self.infoDictionary[GBAControllerSkinIdentifierKey];
}

- (GBAControllerSkinType)type
{
    id typeObject = self.infoDictionary[GBAControllerSkinTypeKey];
    
    GBAControllerSkinType type = GBAControllerSkinTypeGBA;
    
    if ([typeObject isKindOfClass:[NSString class]])
    {
        if ([[(NSString *)typeObject lowercaseString] isEqualToString:@"gbc"])
        {
            type = GBAControllerSkinTypeGBC;
        }
        else
        {
            type = GBAControllerSkinTypeGBA;
        }
    }
    else
    {
        type = [(NSNumber *)typeObject integerValue];
    }
    
    return type;
}

- (GBAControllerSkinDeviceType)deviceType
{
    __block GBAControllerSkinDeviceType deviceType = 0;
    
    void (^enumerateAssets)(NSString *key, NSString *object, BOOL *stop) = ^(NSString *key, NSString *object, BOOL *stop) {
        
        if (([key hasPrefix:@"iPhone"] || [key isEqualToString:GBAScreenTypeResizableiPhone]) && object != nil)
        {
            deviceType |= GBAControllerSkinDeviceTypeiPhone;
        }
        
        if (([key hasPrefix:@"iPad"] || [key isEqualToString:GBAScreenTypeResizableiPad]) && object != nil)
        {
            deviceType |= GBAControllerSkinDeviceTypeiPad;
        }
    };
    
    NSDictionary *portraitDictionary = [self dictionaryForOrientation:GBAControllerSkinOrientationPortrait];
    NSDictionary *portraitAssets = portraitDictionary[GBAControllerSkinAssetsKey];
    
    NSDictionary *landscapeDictionary = [self dictionaryForOrientation:GBAControllerSkinOrientationLandscape];
    NSDictionary *landscapeAssets = landscapeDictionary[GBAControllerSkinAssetsKey];
    
    [portraitAssets enumerateKeysAndObjectsUsingBlock:enumerateAssets];
    [landscapeAssets enumerateKeysAndObjectsUsingBlock:enumerateAssets];
    
    return deviceType;
}

- (BOOL)debug
{
    return [self.infoDictionary[GBAControllerSkinDebugKey] boolValue];
}

- (NSString *)designerName
{
    NSDictionary *designer = self.infoDictionary[GBAControllerSkinDesignerKey];
    return designer[GBAControllerSkinNameKey];
}

- (NSURL *)designerURL
{
    NSDictionary *designer = self.infoDictionary[GBAControllerSkinDesignerKey];
    NSString *designerAddress = designer[GBAControllerSkinURLKey];
    
    return [NSURL URLWithString:designerAddress];
}

- (UIImage *)imageForOrientation:(GBAControllerSkinOrientation)orientation
{
    UIImage *image = nil;
    
    if (orientation == GBAControllerSkinOrientationPortrait)
    {
        image = self.portraitImage;
    }
    else
    {
        image = self.landscapeImage;
    }
    
    if (image == nil)
    {
        NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
        NSDictionary *assets = dictionary[GBAControllerSkinAssetsKey];
        
        NSString *screenType = [self screenTypeForCurrentDeviceWithDictionary:assets orientation:orientation];
        NSString *relativePath = assets[screenType];
        
        if (relativePath == nil)
        {
            return nil; // Invisible Skin for External Controller
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:[self.filepath stringByAppendingPathComponent:relativePath]];
        
        NSString *type = nil;
        NSError *error = nil;
        
        [fileURL getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error];
        
        if (UTTypeConformsTo((__bridge CFStringRef)type, kUTTypePDF))
        {
            CGSize windowSize = [UIApplication sharedApplication].delegate.window.bounds.size;
            
            if (orientation == GBAControllerSkinOrientationPortrait)
            {
                if (windowSize.width > windowSize.height)
                {
                    windowSize = CGSizeMake(windowSize.height, windowSize.width);
                }
                
                image = [UIImage imageWithPDFURL:fileURL atWidth:windowSize.width];
            }
            else
            {
                if (windowSize.height > windowSize.width)
                {
                    windowSize = CGSizeMake(windowSize.height, windowSize.width);
                }
                
                image = [UIImage imageWithPDFURL:fileURL fitSize:windowSize];
            }
            
            // If using a @1x image on a @2x display, we need to change the image's scale to be @1x
            image = [UIImage imageWithCGImage:image.CGImage scale:[self imageScaleForScreenType:screenType] orientation:image.imageOrientation];
        }
        else
        {
            CGFloat scale = [self imageScaleForScreenType:screenType];
            image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:fileURL] scale:scale];
        }
        
        if (orientation == GBAControllerSkinOrientationPortrait)
        {
            self.portraitImage = image;
        }
        else
        {
            self.landscapeImage = image;
        }
    }
    
    return image;
}

- (BOOL)imageExistsForOrientation:(GBAControllerSkinOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[GBAControllerSkinAssetsKey];
    
    NSString *screenType = [self screenTypeForCurrentDeviceWithDictionary:assets orientation:orientation];
    NSString *relativePath = assets[screenType];
    
    return (relativePath != nil);
}

- (BOOL)isTranslucentForOrientation:(GBAControllerSkinOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    return [dictionary[@"translucent"] boolValue];
}

- (BOOL)isResizableForOrientation:(GBAControllerSkinOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[GBAControllerSkinAssetsKey];
    
    NSString *filename = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        filename = assets[GBAScreenTypeResizableiPad];
    }
    else
    {
        filename = assets[GBAScreenTypeResizableiPhone];
    }
    
    return (filename != nil);
}

- (GBAControllerSkinOrientation)supportedOrientations
{
    GBAControllerSkinOrientation supportedOrientations = 0;
    
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

#pragma mark - Mappings -

- (CGRect)frameForMapping:(GBAControllerSkinMapping)mapping orientation:(GBAControllerSkinOrientation)orientation controllerDisplaySize:(CGSize)displaySize
{
    return [self frameForMapping:mapping orientation:orientation controllerDisplaySize:displaySize useExtendedEdges:YES];
}

- (CGRect)frameForMapping:(GBAControllerSkinMapping)mapping orientation:(GBAControllerSkinOrientation)orientation controllerDisplaySize:(CGSize)displaySize useExtendedEdges:(BOOL)useExtendedEdges
{
    CGRect rect = CGRectZero;
    CGSize mappingSize = [self mappingSizeForOrientation:orientation];
    
    if (mapping == GBAControllerSkinMappingControllerImage)
    {
        UIImage *image = [self imageForOrientation:orientation];
        rect = CGRectMake(0, 0, image.size.width, image.size.height);
        
        mappingSize = image.size;
    }
    else
    {
        NSDictionary *layouts = [self dictionaryForOrientation:orientation][GBAControllerSkinLayoutsKey];
        
        NSString *screenType = [self screenTypeForCurrentDeviceWithDictionary:layouts orientation:orientation];
        NSDictionary *mappings = layouts[screenType];
        
        NSString *mappingKey = [self keyForMapping:mapping];
        NSDictionary *mappingDictionary = mappings[mappingKey];
        
        rect = CGRectMake([mappingDictionary[GBAControllerSkinLayoutXKey] floatValue],
                                 [mappingDictionary[GBAControllerSkinLayoutYKey] floatValue],
                                 [mappingDictionary[GBAControllerSkinLayoutWidthKey] floatValue],
                                 [mappingDictionary[GBAControllerSkinLayoutHeightKey] floatValue]);
        
        // The screen size should be absolute, no extended edges
        if (mappingDictionary && useExtendedEdges && mapping != GBAControllerSkinMappingScreen)
        {
            NSDictionary *extendedEdges = mappings[GBAControllerSkinExtendedEdgesKey];
            
            CGFloat topEdge = [extendedEdges[GBAControllerSkinExtendedEdgesTopKey] floatValue];
            CGFloat bottomEdge = [extendedEdges[GBAControllerSkinExtendedEdgesBottomKey] floatValue];
            CGFloat leftEdge = [extendedEdges[GBAControllerSkinExtendedEdgesLeftKey] floatValue];
            CGFloat rightEdge = [extendedEdges[GBAControllerSkinExtendedEdgesRightKey] floatValue];
            
            // Override master extendedEdges with a specific one for an individual button rect if it exists
            if (mappingDictionary[GBAControllerSkinExtendedEdgesKey])
            {
                NSDictionary *buttonExtendedEdges = mappingDictionary[GBAControllerSkinExtendedEdgesKey];
                
                if (buttonExtendedEdges)
                {
                    // Check if non-nil instead of not-zero so 0 can override the general extended edge
                    if (buttonExtendedEdges[GBAControllerSkinExtendedEdgesTopKey])
                    {
                        topEdge = [buttonExtendedEdges[GBAControllerSkinExtendedEdgesTopKey] floatValue];
                    }
                    
                    if (buttonExtendedEdges[GBAControllerSkinExtendedEdgesBottomKey])
                    {
                        bottomEdge = [buttonExtendedEdges[GBAControllerSkinExtendedEdgesBottomKey] floatValue];
                    }
                    
                    if (buttonExtendedEdges[GBAControllerSkinExtendedEdgesLeftKey])
                    {
                        leftEdge = [buttonExtendedEdges[GBAControllerSkinExtendedEdgesLeftKey] floatValue];
                    }
                    
                    if (buttonExtendedEdges[GBAControllerSkinExtendedEdgesRightKey])
                    {
                        rightEdge = [buttonExtendedEdges[GBAControllerSkinExtendedEdgesRightKey] floatValue];
                    }
                }
            }
            
            rect.origin.x -= leftEdge;
            rect.origin.y -= topEdge;
            rect.size.width += leftEdge + rightEdge;
            rect.size.height += topEdge + bottomEdge;
        }
    }    
    
    if (!CGSizeEqualToSize(displaySize, CGSizeZero) && !CGSizeEqualToSize(mappingSize, CGSizeZero))
    {
        CGFloat scale = 1.0;
        
        if (orientation == GBAControllerSkinOrientationPortrait)
        {
            scale = displaySize.width / mappingSize.width;
        }
        else
        {
            CGFloat horizontalScale = displaySize.width / mappingSize.width;
            CGFloat verticalScale = displaySize.height / mappingSize.height;
            scale = fminf(horizontalScale, verticalScale);
        }
        
        rect.origin.x *= scale;
        rect.origin.y *= scale;
        rect.size.width *= scale;
        rect.size.height *= scale;
    }
        
    return rect;
}

#pragma mark - Helper Methods -

- (CGFloat)imageScaleForScreenType:(NSString *)screenType
{
    CGFloat imageScale = 2.0f;
    
    if ([screenType isEqualToString:GBAScreenTypeiPhone5_5])
    {
        imageScale = 3.0f;
    }
    else if ([screenType isEqualToString:GBAScreenTypeiPad])
    {
        imageScale = 1.0f;
    }
    else
    {
        imageScale = 2.0f;
    }
    
    return imageScale;
}

- (NSDictionary *)dictionaryForOrientation:(GBAControllerSkinOrientation)orientation
{
    NSDictionary *dictionary = nil;
    
    switch (orientation) {
        case GBAControllerSkinOrientationPortrait:
            dictionary = self.infoDictionary[GBAControllerSkinOrientationPortraitKey];
            break;
            
        case GBAControllerSkinOrientationLandscape:
            dictionary = self.infoDictionary[GBAControllerSkinOrientationLandscapeKey];
            break;
    }
    
    return dictionary;
}

- (NSString *)screenTypeForCurrentDeviceWithDictionary:(NSDictionary *)dictionary orientation:(GBAControllerSkinOrientation)orientation
{
    NSString *screenType = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        if ([[UIScreen mainScreen] is5_5inches])
        {
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhone5_5])
            {
                screenType = GBAScreenTypeiPhone5_5;
            }
        }
        else if ([[UIScreen mainScreen] is4_7inches])
        {
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhone4_7])
            {
                screenType = GBAScreenTypeiPhone4_7;
            }
        }
        else if ([[UIScreen mainScreen] is4inches])
        {
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhone4_0])
            {
                screenType = GBAScreenTypeiPhone4_0;
            }
        }
        else
        {
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhone])
            {
                screenType = GBAScreenTypeiPhone;
            }
        }
        
        // Because we resize skins to fit screen, we start at highest resolution and work our way down as a fallback mechanism
        if (screenType == nil)
        {
            if ([self isResizableForOrientation:orientation])
            {
                screenType = GBAScreenTypeResizableiPhone;
            }
            else if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhone5_5])
            {
                screenType = GBAScreenTypeiPhone5_5;
            }
            else if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhone4_7])
            {
                screenType = GBAScreenTypeiPhone4_7;
            }
            else if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhone4_0])
            {
                screenType = GBAScreenTypeiPhone4_0;
            }
            else if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPhoneWidescreen])
            {
                screenType = GBAScreenTypeiPhoneWidescreen;
            }
            else
            {
                screenType = GBAScreenTypeiPhone;
            }
        }
    }
    else
    {
        if ([[UIScreen mainScreen] scale] > 1.0)
        {
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPadRetina])
            {
                screenType = GBAScreenTypeiPadRetina;
            }
        }
        else
        {
            if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPad])
            {
                screenType = GBAScreenTypeiPad;
            }
        }
        
        // Because we resize skins to fit screen, we start at highest resolution and work our way down as a fallback mechanism
        if (screenType == nil)
        {
            if ([self isResizableForOrientation:orientation])
            {
                screenType = GBAScreenTypeResizableiPad;
            }
            else if ([GBAControllerSkin validObjectExistsInDictionary:dictionary forKey:GBAScreenTypeiPadRetina])
            {
                screenType = GBAScreenTypeiPadRetina;
            }
            else
            {
                screenType = GBAScreenTypeiPad;
            }
        }
    }
        
    return screenType;
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

- (CGSize)mappingSizeForOrientation:(GBAControllerSkinOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *layouts = dictionary[GBAControllerSkinLayoutsKey];
    
    NSString *screenType = [self screenTypeForCurrentDeviceWithDictionary:layouts orientation:orientation];
    NSDictionary *layoutDictionary = layouts[screenType];
    
    NSDictionary *mappingSizeDictionary = layoutDictionary[GBAControllerSkinMappingSizeKey];
    CGSize mappingSize = CGSizeZero;
    
    if (mappingSizeDictionary)
    {
        mappingSize = CGSizeMake([mappingSizeDictionary[GBAControllerSkinMappingSizeWidthKey] floatValue], [mappingSizeDictionary[GBAControllerSkinMappingSizeHeightKey] floatValue]);
    }
    else
    {
        mappingSize = [self imageForOrientation:orientation].size;
    }
    
    return mappingSize;
}

- (NSString *)keyForMapping:(GBAControllerSkinMapping)mapping
{
    NSString *key = nil;
    switch (mapping) {
        case GBAControllerSkinMappingDPad:
            key = @"dpad";
            break;
            
        case GBAControllerSkinMappingA:
            key = @"a";
            break;
            
        case GBAControllerSkinMappingB:
            key = @"b";
            break;
            
        case GBAControllerSkinMappingAB:
            key = @"ab";
            break;
            
        case GBAControllerSkinMappingStart:
            key = @"start";
            break;
            
        case GBAControllerSkinMappingSelect:
            key = @"select";
            break;
            
        case GBAControllerSkinMappingL:
            key = @"l";
            break;
            
        case GBAControllerSkinMappingR:
            key = @"r";
            break;
            
        case GBAControllerSkinMappingMenu:
            key = @"menu";
            break;
            
        case GBAControllerSkinMappingScreen:
            key = @"screen";
            break;
            
        case GBAControllerSkinMappingControllerImage:
            key = nil;
            break;
    }
    
    return key;
}

#pragma mark - Equality Testing -

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GBAControllerSkin class]])
    {
        return NO;
    }
    
    GBAControllerSkin *controllerSkin = object;
    return (([self.filepath isEqualToString:controllerSkin.filepath] || (self.filepath == nil && controllerSkin.filepath == nil)) && [self.filename isEqualToString:controllerSkin.filename] && [self.infoDictionary isEqual:controllerSkin.infoDictionary]);
}

- (NSUInteger)hash
{
    return [self.filepath hash] + [self.filename hash] + [self.infoDictionary hash];
}


@end
