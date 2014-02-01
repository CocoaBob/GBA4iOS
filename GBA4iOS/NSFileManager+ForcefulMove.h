//
//  NSFileManager+ForcefulMove.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/31/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (ForcefulMove)

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath replaceExistingFile:(BOOL)replaceExistingFile error:(NSError **)error;
- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL replaceExistingFile:(BOOL)replaceExistingFile error:(NSError **)error;

@end
