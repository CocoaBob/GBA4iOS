//
//  NSFileManager+ForcefulMove.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/31/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "NSFileManager+ForcefulMove.h"

@implementation NSFileManager (ForcefulMove)

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath replaceExistingFile:(BOOL)replaceExistingFile error:(NSError **)error
{
    return [self moveItemAtURL:[NSURL fileURLWithPath:srcPath] toURL:[NSURL fileURLWithPath:dstPath] replaceExistingFile:replaceExistingFile error:error];
}

- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL replaceExistingFile:(BOOL)replaceExistingFile error:(NSError *__autoreleasing *)error
{
    if ([self fileExistsAtPath:dstURL.path] && replaceExistingFile)
    {
        return [self replaceItemAtURL:dstURL withItemAtURL:srcURL backupItemName:nil options:0 resultingItemURL:nil error:nil];
    }
    
    return [self moveItemAtURL:srcURL toURL:dstURL error:error];
}

@end
