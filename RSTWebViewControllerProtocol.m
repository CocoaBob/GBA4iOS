//
//  RSTWebViewControllerProtocol.m
//  RSTWebDemo
//
//  Created by Riley Testut on 9/24/13.
//  Copyright (c) 2013 Riley Testut. All rights reserved.
//

#import "RSTWebViewControllerProtocol.h"

@interface RSTWebViewControllerProtocol ()

@property (nonatomic, strong) NSURLConnection *connection;
@property (assign, nonatomic) long long downloadSize;

@end

@implementation RSTWebViewControllerProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if ([NSURLProtocol propertyForKey:@"UserAgentSet" inRequest:request] != nil)
        return NO;
    
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    
    // Here we set the User Agent
    [newRequest setValue:@"Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.2 Safari/537.36 Kifi/1.0f" forHTTPHeaderField:@"User-Agent"];
    
    [NSURLProtocol setProperty:@YES forKey:@"UserAgentSet" inRequest:newRequest];
    
    self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
}

- (void)stopLoading
{
    [self.connection cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.client URLProtocol:self didFailWithError:error];
    self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    NSInteger statusCode = [response statusCode];
    if (statusCode == 200)
    {
        self.downloadSize = [response expectedContentLength];
    }
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"Done");
    
    [self.client URLProtocolDidFinishLoading:self];
    self.connection = nil;
}

@end
