//
//  DBFILESFileMetadata+Coding.m
//  GBA4iOS
//
//  Created by Spencer Atkin on 10/12/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

#import "DBFILESFileMetadata+Coding.h"

@implementation DBFILESFileMetadata (Coding)
-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [DBFILESFileMetadataSerializer deserialize:[aDecoder decodeObjectForKey:@"serializedDict"]];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[DBFILESFileMetadataSerializer serialize:self] forKey:@"serializedDict"];
}
@end
