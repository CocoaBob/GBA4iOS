//
//  DBFILESFileMetadata+Coding.h
//  GBA4iOS
//
//  Created by Spencer Atkin on 10/12/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>

@interface DBFILESFileMetadata (Coding) <NSCoding>
-(instancetype)initWithCoder:(NSCoder *)aDecoder;
- (void)encodeWithCoder:(NSCoder *)aCoder;
@end
