//
//  GBACheatTextView.m
//  GBA4iOS
//
//  Created by Riley Testut on 1/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import "GBACheatTextView.h"

@implementation GBACheatTextView

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        
    }
    
    return self;
}

- (void)setCheatCodeType:(GBACheatCodeType)cheatCodeType
{
    if (_cheatCodeType == cheatCodeType)
    {
        return;
    }
    
    _cheatCodeType = cheatCodeType;
    
    CGFloat characterWidth = 15.6533203125;
    
    // Character Width: 15.6533203125
    // 8 + 8 Letters: 125.2265625, 266.1064453125
    // 8 + 4 Letters: 125.2265625, 203.4931640625
    // 8 Letters: 125.2265625
    // 3 + 3 + 3: 46.9599609375, 109.5732421875, 172.1865234375
    
    NSArray *exclusionPaths = nil;
    
    switch (cheatCodeType)
    {
        case GBACheatCodeTypeActionReplay:
        {
            UIBezierPath *firstSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 9, 0, characterWidth, CGFLOAT_MAX)];
            UIBezierPath *trailingSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 19, 0, CGFLOAT_MAX, CGFLOAT_MAX)];
            exclusionPaths = @[firstSpace, trailingSpace];
            break;
        }
            
        case GBACheatCodeTypeGameSharkV3:
        {
            UIBezierPath *firstSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 9, 0, characterWidth, CGFLOAT_MAX)];
            UIBezierPath *trailingSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 19, 0, CGFLOAT_MAX, CGFLOAT_MAX)];
            exclusionPaths = @[firstSpace, trailingSpace];
            break;
        }
            
        case GBACheatCodeTypeCodeBreaker:
        {
            UIBezierPath *firstSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 9, 0, characterWidth, CGFLOAT_MAX)];
            UIBezierPath *trailingSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 15, 0, CGFLOAT_MAX, CGFLOAT_MAX)];
            exclusionPaths = @[firstSpace, trailingSpace];
            break;
        }
            
        case GBACheatCodeTypeGameSharkGBC:
        {
            UIBezierPath *trailingSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 9, 0, CGFLOAT_MAX, CGFLOAT_MAX)];
            exclusionPaths = @[trailingSpace];
            break;
        }
            
        case GBACheatCodeTypeGameGenie:
        {
            UIBezierPath *firstSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 4, 0, characterWidth, CGFLOAT_MAX)];
            UIBezierPath *secondSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 9, 0, characterWidth, CGFLOAT_MAX)];
            UIBezierPath *trailingSpace = [UIBezierPath bezierPathWithRect:CGRectMake(characterWidth * 14, 0, CGFLOAT_MAX, CGFLOAT_MAX)];
            exclusionPaths = @[firstSpace, secondSpace, trailingSpace];
            break;
        }
    }
    
    self.textContainer.exclusionPaths = exclusionPaths;
    
    
    //NSAttributedString *attributedString = [[NSAttributedString alloc] initWithAttributedString:self.attributedText];
    
    //DLog(@"Size: %@", NSStringFromCGSize([attributedString size]));
    
    
}


@end
