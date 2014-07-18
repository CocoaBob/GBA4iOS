//
//  GBAEvent.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/29/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBAEvent.h"

#import "NSDate+Comparing.h"

@interface GBAEvent ()

@property (readwrite, copy, nonatomic) NSString *name;
@property (readwrite, copy, nonatomic) NSString *blurb;
@property (readwrite, copy, nonatomic) NSString *eventDescription;
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
        _blurb = [dictionary[@"blurb"] copy];
        _eventDescription = [dictionary[@"description"] copy];
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
    [aCoder encodeObject:self.name forKey:NSStringFromSelector(@selector(name))];
    [aCoder encodeObject:self.identifier forKey:NSStringFromSelector(@selector(identifier))];
    [aCoder encodeObject:self.blurb forKey:NSStringFromSelector(@selector(blurb))];
    [aCoder encodeObject:self.eventDescription forKey:NSStringFromSelector(@selector(eventDescription))];
    [aCoder encodeObject:@(self.supportedGames) forKey:NSStringFromSelector(@selector(supportedGames))];
    [aCoder encodeObject:self.endDate forKey:NSStringFromSelector(@selector(endDate))];
    [aCoder encodeObject:@(self.apiVersion) forKey:NSStringFromSelector(@selector(apiVersion))];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSString *name = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(name))];
    NSString *identifier = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(identifier))];
    NSString *blurb = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(blurb))];
    NSString *eventDescription = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(eventDescription))];
    GBAEventSupportedGame supportedGames = [[aDecoder decodeObjectForKey:NSStringFromSelector(@selector(supportedGames))] integerValue];
    NSDate *endDate = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(endDate))];
    NSInteger apiVersion = [[aDecoder decodeObjectForKey:NSStringFromSelector(@selector(apiVersion))] integerValue];
    
    if (blurb == nil)
    {
        blurb = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(description))];
    }
    
    if (eventDescription == nil)
    {
        eventDescription = [aDecoder decodeObjectForKey:@"detailedDescription"];
    }
    
    self = [self init];
    self.name = name;
    self.identifier = identifier;
    self.blurb = blurb;
    self.eventDescription = eventDescription;
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

- (NSString *)description
{
    return self.name;
}

#pragma mark - Getters/Setters

- (BOOL)isExpired
{
    return (self.endDate && [[NSDate date] daysUntilDate:self.endDate] < 0);
}

- (NSString *)localizedSupportedGames
{
    NSMutableArray *supportedGames = [NSMutableArray array];
    
    if ([self supportsGame:GBAEventSupportedGameRuby])
    {
        [supportedGames addObject:NSLocalizedString(@"Ruby", @"The Pokemon game Ruby, not the jewel")];
    }
    if ([self supportsGame:GBAEventSupportedGameSapphire])
    {
        [supportedGames addObject:NSLocalizedString(@"Sapphire", @"The Pokemon game Sapphire, not the jewel")];
    }
    if ([self supportsGame:GBAEventSupportedGameFireRed])
    {
        [supportedGames addObject:NSLocalizedString(@"FireRed", @"The Pokemon game FireRed")];
    }
    if ([self supportsGame:GBAEventSupportedGameLeafGreen])
    {
        [supportedGames addObject:NSLocalizedString(@"LeafGreen", @"The Pokemon game LeafGreen")];
    }
    if ([self supportsGame:GBAEventSupportedGameEmerald])
    {
        [supportedGames addObject:NSLocalizedString(@"Emerald", @"The Pokemon game Emerald, not the jewel")];
    }
    
    if (supportedGames.count == 0)
    {
        return nil;
    }
    
    NSMutableString *localizedSupportedGames = [NSMutableString stringWithFormat:NSLocalizedString(@"Pokémon", @"")];
    
    [supportedGames enumerateObjectsUsingBlock:^(NSString *game, NSUInteger index, BOOL *stop) {
        
        if (index != 0)
        {
            if (supportedGames.count > 2)
            {
                [localizedSupportedGames appendString:@","];
            }
            
            if (index == supportedGames.count - 1)
            {
                [localizedSupportedGames appendFormat:@" %@", NSLocalizedString(@"and", @"")];
            }
        }
        
        [localizedSupportedGames appendFormat:@" %@", game];
        
    }];
    
    return localizedSupportedGames;
}

@end
