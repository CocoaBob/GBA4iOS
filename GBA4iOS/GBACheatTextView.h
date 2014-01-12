//
//  GBACheatTextView.h
//  GBA4iOS
//
//  Created by Riley Testut on 1/11/14.
//  Copyright (c) 2014 Riley Testut. All rights reserved.
//

#import <PSPDFTextView/PSPDFTextView.h>

#import "GBACheat.h"

@interface GBACheatTextView : PSPDFTextView

@property (assign, nonatomic) GBACheatCodeType cheatCodeType;

@end
