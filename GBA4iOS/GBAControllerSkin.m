//
//  GBAControllerSkin.m
//  GBA4iOS
//
//  Created by Riley Testut on 7/27/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "GBAControllerSkin.h"

@interface GBAControllerSkin ()

@property (copy, nonatomic) NSString *directory;
@property (copy, nonatomic) NSDictionary *infoDictionary;

@end

@implementation GBAControllerSkin

#pragma mark - Init

- (instancetype)initWithDirectory:(NSString *)directory
{
    self = [super init];
    if (self)
    {
        _directory = [directory copy];
        _infoDictionary = [NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:@"Info.plist"]];
    }
    
    return self;
}

#pragma mark - Public

- (UIImage *)imageForOrientation:(GBAControllerSkinOrientation)orientation
{
    NSDictionary *dictionary = [self dictionaryForOrientation:orientation];
    NSDictionary *assets = dictionary[@"Assets"];
    NSString *relativePath = assets[@"Retina"];
    NSString *filepath = [self.directory stringByAppendingPathComponent:relativePath];
    
    return [[UIImage alloc] initWithData:[NSData dataWithContentsOfFile:filepath] scale:2.0];
}

#pragma mark - Private

- (NSDictionary *)dictionaryForOrientation:(GBAControllerSkinOrientation)orientation
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

@end
