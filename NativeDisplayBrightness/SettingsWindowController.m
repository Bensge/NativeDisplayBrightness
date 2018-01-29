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
    
    self.multiMonitor.state = APP_DELEGATE.multiMonitor;
    self.smoothStep.state = APP_DELEGATE.smoothStep;
    self.showBrightness.state = APP_DELEGATE.showBrightness;
    [self.maxBrightness selectItemWithTag: APP_DELEGATE.maxBrightness];
    self.adjustColorTemperature.state = APP_DELEGATE.adjustColorTemperature;
    self.colorTemperatureLimit.floatValue = APP_DELEGATE.colorTemperatureLimit;
    self.colorTemperatureLimit.enabled = self.adjustColorTemperature.state;
    
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

- (IBAction)maxBrightness:(NSPopUpButton *)sender {
    APP_DELEGATE.maxBrightness = (int)sender.selectedTag;
}

- (IBAction)adjustColorTemperature:(NSButton *)sender {
    APP_DELEGATE.adjustColorTemperature = sender.state;
    self.colorTemperatureLimit.enabled = sender.state;
}

- (IBAction)colorTemperatureLimit:(NSSlider *)sender {
    APP_DELEGATE.colorTemperatureLimit = sender.floatValue;
}


@end
