//
//  GBAEvent.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/29/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAEvent.h"

@interface GBAEvent ()

@property (readwrite, copy, nonatomic) NSString *name;
@property (readwrite, copy, nonatomic) NSString *description;
@property (readwrite, copy, nonatomic) NSString *detailedDescription;
@property (readwrite, copy, nonatomic) NSString *identifier;
@property (readwrite, copy, nonatomic) NSDate *endDate;
@property (readwrite, assign, nonatomic) GBAEventSupportedGame supportedGames;
@property (readwrite, assign, nonatomic) NSInteger apiVersion;

@end

@implementation GBAEvent

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    if (dictionary == nil)
    {
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _name = [dictionary[@"name"] copy];
        _description = [dictionary[@"description"] copy];
        _detailedDescription = [dictionary[@"detailedDescription"] copy];
        _identifier = [dictionary[@"identifier"] copy];
        
        _apiVersion = 1;
        
        NSString *endDateString = dictionary[@"endDate"];
        
        if (endDateString)
        {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"MM/dd/yyyy"];
            _endDate = [[dateFormatter dateFromString:endDateString] copy];
        }
        
        [self sanitizeSupportedGames:dictionary[@"games"]];
    }
    
    return self;
}

+ (instancetype)eventWithContentsOfFile:(NSString *)filepath
{
    GBAEvent *event = [NSKeyedUnarchiver unarchiveObjectWithFile:filepath];
    return event;
}

+ (instancetype)eventWithDictionary:(NSDictionary *)dictionary
{
    GBAEvent *event = [[GBAEvent alloc] initWithDictionary:dictionary];
    return event;
}

#pragma mark - Public

- (void)writeToFile:(NSString *)filepath
{
    [NSKeyedArchiver archiveRootObject:self toFile:filepath];
}

- (BOOL)supportsGame:(GBAEventSupportedGame)supportedGame
{
    return (self.supportedGames & supportedGame) == supportedGame;
}

#pragma mark - Private

- (void)sanitizeSupportedGames:(NSArray *)supportedGames
{
    if ([supportedGames containsObject:@"Ruby"])
    {
        self.supportedGames |= GBAEventSupportedGameRuby;
    }
    
    if ([supportedGames containsObject:@"Sapphire"])
    {
        self.supportedGames |= GBAEventSupportedGameSapphire;
    }
    
    if ([supportedGames containsObject:@"FireRed"])
    {
        self.supportedGames |= GBAEventSupportedGameFireRed;
    }
    
    if ([supportedGames containsObject:@"LeafGreen"])
    {
        self.supportedGames |= GBAEventSupportedGameLeafGreen;
    }
    
    if ([supportedGames containsObject:@"Emerald"])
    {
        self.supportedGames |= GBAEventSupportedGameEmerald;
    }
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.identifier forKey:@"identifier"];
    [aCoder encodeObject:self.description forKey:@"description"];
    [aCoder encodeObject:self.detailedDescription forKey:@"detailedDescription"];
    [aCoder encodeObject:@(self.supportedGames) forKey:@"supportedGames"];
    [aCoder encodeObject:self.endDate forKey:@"endDate"];
    [aCoder encodeObject:@(self.apiVersion) forKey:@"apiVersion"];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = [aDecoder decodeObjectForKey:@"name"];
    NSString *identifier = [aDecoder decodeObjectForKey:@"identifier"];
    NSString *description = [aDecoder decodeObjectForKey:@"description"];
    NSString *detailedDescription = [aDecoder decodeObjectForKey:@"detailedDescription"];
    GBAEventSupportedGame supportedGames = [[aDecoder decodeObjectForKey:@"supportedGames"] integerValue];
    NSDate *endDate = [aDecoder decodeObjectForKey:@"endDate"];
    NSInteger apiVersion = [[aDecoder decodeObjectForKey:@"apiVersion"] integerValue];
    
    self = [self init];
    self.name = name;
    self.identifier = identifier;
    self.description = description;
    self.detailedDescription = detailedDescription;
    self.supportedGames = supportedGames;
    self.endDate = endDate;
    self.apiVersion = apiVersion;
    
    return self;
}

#pragma mark - Misc.

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GBAEvent class]])
    {
        return NO;
    }
    
    return [self.identifier isEqualToString:[(GBAEvent *)object identifier]];
}

- (NSUInteger)hash
{
    return [self.identifier hash];
}

@end
