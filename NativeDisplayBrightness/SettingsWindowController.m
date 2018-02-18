//
//  SettingsWindowController.m
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/28/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import "SettingsWindowController.h"
#import "Config.h"

@interface SettingsWindowController ()

@end

@implementation SettingsWindowController

-(void)windowDidLoad {
    [super windowDidLoad];

    [self.decreaseBrightnessKey removeAllItems];
    [self.increaseBrightnessKey removeAllItems];
    [self.colorTemperatureLessWarmKey removeAllItems];
    [self.colorTemperatureMoreWarmKey removeAllItems];
    
    for (int i = 1; i <= 20; i++) {
        NSString *item = [NSString stringWithFormat:@"F%d",i];
        [self.decreaseBrightnessKey addItemWithTitle:item];
        [self.increaseBrightnessKey addItemWithTitle:item];
        [self.colorTemperatureLessWarmKey addItemWithTitle:item];
        [self.colorTemperatureMoreWarmKey addItemWithTitle:item];
    }
    [self.increaseBrightnessKey selectItemWithTitle:APP_DELEGATE.increaseBrightnessKey];
    [self.decreaseBrightnessKey selectItemWithTitle:APP_DELEGATE.decreaseBrightnessKey];
    [self.colorTemperatureLessWarmKey selectItemWithTitle:APP_DELEGATE.colorTemperatureLessWarmKey];
    [self.colorTemperatureMoreWarmKey selectItemWithTitle:APP_DELEGATE.colorTemperatureMoreWarmKey];
    
    [self updateKeys];
    
    self.multiMonitor.state = APP_DELEGATE.multiMonitor;
    self.smoothStep.state = APP_DELEGATE.smoothStep;
    self.showBrightness.state = APP_DELEGATE.showBrightness;
    [self.maxBrightness selectItemWithTag: APP_DELEGATE.maxBrightness];
    
    self.adjustColorTemperature.state = APP_DELEGATE.adjustColorTemperature;
    self.colorTemperatureLimit.floatValue = APP_DELEGATE.colorTemperatureLimit;
    
    [self updateColorTemperatureStates:self.adjustColorTemperature.state];
    
    //system not supports it, disable all controls
    if (!APP_DELEGATE.supportsBlueLightReduction) {
        self.adjustColorTemperature.enabled = NO;
        self.colorTemperatureLimit.enabled = NO;
    }
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp stopModal];
}

- (IBAction)multiMonitor:(NSButton *)sender {
    APP_DELEGATE.multiMonitor = sender.state;
}

- (IBAction)smoothStep:(NSButton *)sender {
    APP_DELEGATE.smoothStep = sender.state;
}

- (IBAction)showBrightness:(NSButton *)sender {
    APP_DELEGATE.showBrightness = sender.state;
    if (sender.state == NSControlStateValueOn) {
        APP_DELEGATE.statusBarIcon.title = [NSString stringWithFormat:@"%i%%",APP_DELEGATE.currentBrightness];
        APP_DELEGATE.statusBarIcon.length = APP_DELEGATE.currentBrightness == 100 ? STATUS_ICON_WIDTH_TEXT_100 : STATUS_ICON_WIDTH_TEXT;
    } else {
        APP_DELEGATE.statusBarIcon.title = @"";
        APP_DELEGATE.statusBarIcon.length = STATUS_ICON_WIDTH;
    }    
}

- (IBAction)changeDecreaseBrightnessKey:(NSPopUpButton *)sender {
    APP_DELEGATE.decreaseBrightnessKey = sender.selectedItem.title;
    [self updateKeys];
}

- (IBAction)changeIncreaseBrightnessKey:(NSPopUpButton *)sender {
    APP_DELEGATE.increaseBrightnessKey = sender.selectedItem.title;
    [self updateKeys];
}

- (IBAction)maxBrightness:(NSPopUpButton *)sender {
    APP_DELEGATE.maxBrightness = (int)sender.selectedTag;
}

- (IBAction)adjustColorTemperature:(NSButton *)sender {
    APP_DELEGATE.adjustColorTemperature = sender.state;
    [self updateColorTemperatureStates:sender.state];
    
    if (!sender.state) {
        [APP_DELEGATE.statusBarMenu removeItem:APP_DELEGATE.colorTemperatureMenu];
    } else {
        [APP_DELEGATE.statusBarMenu insertItem:APP_DELEGATE.colorTemperatureMenu atIndex:1];
    }
}

- (IBAction)colorTemperatureLimit:(NSSlider *)sender {
    APP_DELEGATE.colorTemperatureLimit = sender.floatValue;
}

- (IBAction)changeColorTemperatureLessWarmKey:(NSPopUpButton *)sender {
    APP_DELEGATE.colorTemperatureLessWarmKey = sender.selectedItem.title;
    [self updateKeys];
}

- (IBAction)changeColorTemperatureMoreWarmKey:(NSPopUpButton *)sender {
    APP_DELEGATE.colorTemperatureMoreWarmKey = sender.selectedItem.title;
    [self updateKeys];
}

- (void)updateKeys {

    //needed!? 
//    [self enableAllItems:self.increaseBrightnessKey.itemArray];
//    [self enableAllItems:self.decreaseBrightnessKey.itemArray];
//    [self enableAllItems:self.colorTemperatureLessWarmKey.itemArray];
//    [self enableAllItems:self.colorTemperatureMoreWarmKey.itemArray];
//
//    [self.increaseBrightnessKey itemWithTitle:APP_DELEGATE.decreaseBrightnessKey].enabled = NO;
//    [self.increaseBrightnessKey itemWithTitle:APP_DELEGATE.colorTemperatureLessWarmKey].enabled = NO;
//    [self.increaseBrightnessKey itemWithTitle:APP_DELEGATE.colorTemperatureMoreWarmKey].enabled = NO;
//
//    [self.decreaseBrightnessKey itemWithTitle:APP_DELEGATE.increaseBrightnessKey].enabled = NO;
//    [self.decreaseBrightnessKey itemWithTitle:APP_DELEGATE.colorTemperatureLessWarmKey].enabled = NO;
//    [self.decreaseBrightnessKey itemWithTitle:APP_DELEGATE.colorTemperatureMoreWarmKey].enabled = NO;
//
//    [self.colorTemperatureLessWarmKey itemWithTitle:APP_DELEGATE.increaseBrightnessKey].enabled = NO;
//    [self.colorTemperatureLessWarmKey itemWithTitle:APP_DELEGATE.decreaseBrightnessKey].enabled = NO;
//    [self.colorTemperatureLessWarmKey itemWithTitle:APP_DELEGATE.colorTemperatureMoreWarmKey].enabled = NO;
//
//    [self.colorTemperatureMoreWarmKey itemWithTitle:APP_DELEGATE.increaseBrightnessKey].enabled = NO;
//    [self.colorTemperatureMoreWarmKey itemWithTitle:APP_DELEGATE.decreaseBrightnessKey].enabled = NO;
//    [self.colorTemperatureMoreWarmKey itemWithTitle:APP_DELEGATE.colorTemperatureLessWarmKey].enabled = NO;
}

- (void) enableAllItems:(NSArray *) items {
    for (NSMenuItem *item in items) {
        item.enabled = YES;
    }
}

- (void)updateColorTemperatureStates:(bool) state {
    
    NSColor *color = state ? [NSColor textColor] : [NSColor disabledControlTextColor];
    
    self.colorTemperatureLimit.enabled = state;
    
    self.colorTemperatureLimitLabel.textColor = color;
    self.colorTemperatureLimit.enabled = state;
    
    self.colorTemperatureLessWarmLabel.textColor = color;
    self.colorTemperatureMoreWarmLabel.textColor = color;
    
    self.colorTemperatureLessWarmKeyLabel.textColor = color;
    self.colorTemperatureLessWarmKey.enabled = state;
    
    self.colorTemperatureMoreWarmKeyLabel.textColor = color;
    self.colorTemperatureMoreWarmKey.enabled = state;
}

@end
