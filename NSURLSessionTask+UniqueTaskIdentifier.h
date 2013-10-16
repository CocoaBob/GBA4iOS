//
//  NSURLSessionTask+UniqueTaskIdentifier.h
//
//  Created by Riley Testut on 7/20/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

/* NSURLSessionTask has a taskIdentifier property used to distinguish tasks 
 * from one another. However, this is only on a per-session basis. 
 * RSTWebViewController needs a new session for each instance of itself
 * to assign the delegate value. To prevent taskIdentifiers from conflicting,
 * we create this custom property where we can assign any string, preferably
 * with NSUUID methods.
 */

@interface NSObject (UniqueTaskIdentifier)

@property (copy, nonatomic) NSString *uniqueTaskIdentifier;

@end
