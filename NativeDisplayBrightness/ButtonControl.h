//
//  ButtonControl.h
//  NativeDisplayBrightness
//
//  Created by Ivan_Alone on 09.05.21.
//  Copyright © 2021 Ivan_Alone. All rights reserved.
//

#ifndef ButtonControl_h
#define ButtonControl_h

#import <Cocoa/Cocoa.h>

@interface ButtonControl : NSObject

@property int keyCode;

@property bool isShift;
@property bool isAlt;
@property bool isCmd;
@property bool isCtrl;
@property bool isCaps;
@property bool isFN;

- (bool)verifyKey: (int64_t)keyCode arg2: (int64_t)modifierFlags;

@end

#endif /* ButtonControl_h */
