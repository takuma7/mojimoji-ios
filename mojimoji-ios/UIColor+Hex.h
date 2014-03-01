//
//  UIColor+Hex.h
//  mojimoji-ios
//
//  Created by Takuma YOSHITANI on 3/1/14.
//  Copyright (c) 2014 Takuma YOSHITANI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (Hex)
+ (UIColor *)colorWithHex:(NSString *)colorCode;
+ (UIColor *)colorWithHex:(NSString *)colorCode alpha:(CGFloat)alpha;
@end
