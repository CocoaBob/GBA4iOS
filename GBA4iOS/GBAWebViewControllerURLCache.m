//
//  GBAWebViewControllerURLCache.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/31/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAWebViewControllerURLCache.h"

@interface GBAWebViewControllerURLCache ()

@end

@implementation GBAWebViewControllerURLCache

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request
{
    if (![self replaceInitialRequestWithBlankPage])
    {
        return [super cachedResponseForRequest:request];
    }
        
	//
	// Load the data
	//
	NSData *data = [@"<html><body></body></html>" dataUsingEncoding:NSUTF8StringEncoding];
	
	//
	// Create the cacheable response
	//
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[request URL] MIMEType:@"text/html" expectedContentLength:[data length] textEncodingName:nil];
	NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response data:data];
    
    self.replaceInitialRequestWithBlankPage = NO;
	
	return cachedResponse;
}

@end
