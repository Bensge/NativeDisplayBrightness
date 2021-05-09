//
//  ButtonControl.m
//  NativeDisplayBrightness
//
//  Created by Ivan_Alone on 09.05.21.
//  Copyright © 2021 Ivan_Alone. All rights reserved.
//

#import "ButtonControl.h"

@implementation ButtonControl

- (bool)xorCheckFor: (bool)a And: (bool)b
{
    return (a && b) || (!a && !b);
}

- (bool)verifyKey: (int64_t)keyCode arg2: (int64_t)modifierFlags
{
    return keyCode == self.keyCode &&
    [self xorCheckFor: self.isShift And: (modifierFlags & NSEventModifierFlagShift   )] &&
    [self xorCheckFor: self.isCmd   And: (modifierFlags & NSEventModifierFlagCommand )] &&
    [self xorCheckFor: self.isAlt   And: (modifierFlags & NSEventModifierFlagOption  )] &&
    [self xorCheckFor: self.isCtrl  And: (modifierFlags & NSEventModifierFlagControl )] &&
    (self.isCaps ? (modifierFlags & NSEventModifierFlagCapsLock) : true) &&
    (self.isFN   ? (modifierFlags & NSEventModifierFlagFunction) : true);
}


@end
