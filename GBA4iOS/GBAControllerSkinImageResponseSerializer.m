//
//  GBAControllerSkinImageResponseSerizalier.m
//  GBA4iOS
//
//  Created by Riley Testut on 9/8/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAControllerSkinImageResponseSerializer.h"
#import "UIImage+PDF.h"

@import MobileCoreServices;

@implementation GBAControllerSkinImageResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *__autoreleasing *)error
{
    CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)response.MIMEType, NULL);
    
    UIImage *image = nil;
    
    if (UTTypeConformsTo(type, kUTTypePDF))
    {
        image = [UIImage imageWithPDFData:data fitSize:self.resizableImageTargetSize];
    }
    else
    {
        image = [UIImage imageWithData:data scale:[[UIScreen mainScreen] scale]];
    }
    
    CFRelease(type);
    
    return image;
}

@end
