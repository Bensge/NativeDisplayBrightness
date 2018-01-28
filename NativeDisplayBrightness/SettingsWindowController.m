//
//  SettingsWindowController.m
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/28/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import "SettingsWindowController.h"
#import "AppDelegate.h"

@interface SettingsWindowController ()

@end

@implementation SettingsWindowController

-(void)windowDidLoad {
    [super windowDidLoad];
    
    self.multiMonitor.state = APP_DELEGATE.multiMonitor;
    self.smoothStep.state = APP_DELEGATE.smoothStep;
    self.showBrightness.state = APP_DELEGATE.showBrightness;
    [self.maxBrightness selectItemWithTag: APP_DELEGATE.maxBrightness];
    self.adjustTemp.state = APP_DELEGATE.adjustTemp;
    self.tempLimit.intValue = APP_DELEGATE.tempLimit;
    self.tempLimit.enabled = self.adjustTemp.state;
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
        APP_DELEGATE.statusBarIcon.length = STATUS_ICON_WIDTH_TEXT;
    } else {
        APP_DELEGATE.statusBarIcon.title = @"";
        APP_DELEGATE.statusBarIcon.length = STATUS_ICON_WIDTH;
    }    
}

- (IBAction)maxBrightness:(NSPopUpButton *)sender {
    APP_DELEGATE.maxBrightness = (int)sender.selectedTag;
}

- (IBAction)adjustColorTemp:(NSButton *)sender {
    APP_DELEGATE.adjustTemp = sender.state;
    self.tempLimit.enabled = sender.state;
}

- (IBAction)tempLimit:(NSSlider *)sender {
    APP_DELEGATE.tempLimit = sender.intValue;
}


@end
