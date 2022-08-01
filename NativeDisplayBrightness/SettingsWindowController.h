//
//  SettingsWindowController.h
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/28/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SettingsWindowController : NSWindowController <NSWindowDelegate>

@property (weak) IBOutlet NSButton *multiMonitor;
@property (weak) IBOutlet NSButton *smoothStep;
@property (weak) IBOutlet NSButton *showBrightness;

@property (weak) IBOutlet NSPopUpButton *increaseBrightnessKey;
@property (weak) IBOutlet NSPopUpButton *decreaseBrightnessKey;
@property (weak) IBOutlet NSPopUpButton *maxBrightness;

@property (weak) IBOutlet NSButton *adjustColorTemperature;
@property (weak) IBOutlet NSTextField *colorTemperatureLimitLabel;
@property (weak) IBOutlet NSSlider *colorTemperatureLimit;

@property (weak) IBOutlet NSTextField *colorTemperatureLessWarmLabel;
@property (weak) IBOutlet NSTextField *colorTemperatureMoreWarmLabel;

@property (weak) IBOutlet NSTextField *colorTemperatureLessWarmKeyLabel;
@property (weak) IBOutlet NSPopUpButton *colorTemperatureLessWarmKey;

@property (weak) IBOutlet NSTextField *colorTemperatureMoreWarmKeyLabel;
@property (weak) IBOutlet NSPopUpButton *colorTemperatureMoreWarmKey;


@end
