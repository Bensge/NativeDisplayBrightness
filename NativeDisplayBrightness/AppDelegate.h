//
//  AppDelegate.h
//  NativeDisplayBrightness
//
//  Created by Benno Krauss on 19.10.16.
//  Copyright © 2016 Benno Krauss. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Config.h"

@class BrightnessViewController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) NSStatusItem *statusBarIcon;
@property (strong) NSMenu *statusBarMenu;
@property (strong) BrightnessViewController *brightnessView;
@property (assign) int currentBrightness;

//Settings values
@property (nonatomic, assign) BOOL multiMonitor;
@property (nonatomic, assign) BOOL smoothStep;
@property (nonatomic, assign) BOOL showBrightness;
@property (nonatomic, assign) int maxBrightness;
@property (nonatomic, assign) BOOL adjustTemp;
@property (nonatomic, assign) int tempLimit;

+(BOOL)loadSavedBrightness:(uint*) savedBrightness forDisplayID:(CGDirectDisplayID) displayID;
+(void)changeMainScreenBrightnessWithStep:(int) deltaInSubsteps;
+(void)changeMainScreenBrightness:(int) newBrightness;

@end

