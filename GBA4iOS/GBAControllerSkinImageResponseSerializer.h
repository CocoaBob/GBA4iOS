//
//  GBAControllerSkinImageResponseSerizalier.h
//  GBA4iOS
//
//  Created by Riley Testut on 9/8/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <AFNetworking/AFURLResponseSerialization.h>

@interface GBAControllerSkinImageResponseSerializer : AFHTTPResponseSerializer

@property (assign, nonatomic) CGSize resizableImageTargetSize;

@end
