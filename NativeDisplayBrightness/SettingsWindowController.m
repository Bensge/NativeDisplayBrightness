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
    //TODO: load settings here
    
}

-(void)windowWillClose:(NSNotification *)notification {
    [NSApp stopModal];
}

- (IBAction)multiMonitor:(NSButton *)sender {
    //TODO:
}

- (IBAction)smoothStep:(NSButton *)sender {
    
}

- (IBAction)showBrightness:(NSButton *)sender {
    if (sender.state == NSControlStateValueOn) {
        APP_DELEGATE.statusBarIcon.title = [NSString stringWithFormat:@"%i%%",APP_DELEGATE.currentBrightness];
        APP_DELEGATE.statusBarIcon.length = STATUS_ICON_WIDTH_TEXT;
    } else {
        APP_DELEGATE.statusBarIcon.title = @"";
        APP_DELEGATE.statusBarIcon.length = STATUS_ICON_WIDTH;
    }    
}


- (IBAction)brightnessLimit:(NSPopUpButton *)sender {
    
}

- (IBAction)adjustColorTemp:(NSButton *)sender {
    
}

- (IBAction)changeColorTemp:(NSSlider *)sender {
   
}


@end
