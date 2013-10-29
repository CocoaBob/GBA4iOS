//
//  GBADropboxMonitor.h
//  GBA4iOS
//
//  Created by Riley Testut on 10/29/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

// C variant for use within emulator code
void updateFileAtPath(char *path);

@interface GBADropboxMonitor : NSObject

- (void)updateFileAtPath:(NSString *)path;
- (void)synchronize;

@end
