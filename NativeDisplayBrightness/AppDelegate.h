//
//  AppDelegate.h
//  NativeDisplayBrightness
//
//  Created by Benno Krauss on 19.10.16.
//  Copyright © 2016 Benno Krauss. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Config.h"
#import "CBBlueLightClient.h"

@class BrightnessViewController;
@class ColorTemperatureViewController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) NSStatusItem *statusBarIcon;
@property (strong) NSMenu *statusBarMenu;
@property (strong) BrightnessViewController *brightnessView;

@property (strong) CBBlueLightClient *blueLight;
@property (strong) ColorTemperatureViewController *colorTemperatureView;

//runtime variables
@property (assign) int currentBrightness;
@property (assign) BOOL supportsBlueLightReduction;

//Settings values
@property (nonatomic, assign) BOOL multiMonitor;
@property (nonatomic, assign) BOOL smoothStep;
@property (nonatomic, assign) BOOL showBrightness;
@property (nonatomic, assign) int maxBrightness;

@property (nonatomic, assign) BOOL adjustColorTemperature;
@property (nonatomic, assign) float colorTemperature; //this only shows in slider in menu
@property (nonatomic, assign) float colorTemperatureLimit;

+(BOOL)loadSavedBrightness:(uint*) savedBrightness forDisplayID:(CGDirectDisplayID) displayID;
+(void)changeMainScreenBrightnessWithStep:(int) deltaInSubsteps;
+(void)changeMainScreenBrightness:(int) newBrightness;
+(void)changeScreenColorTemperature:(float) colorTemperature;

@end

