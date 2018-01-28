//
//  SettingsWindowController.m
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/28/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import "SettingsWindowController.h"

@interface SettingsWindowController ()

@end

@implementation SettingsWindowController

-(void) windowDidLoad {
    [super windowDidLoad];
    //TODO: load settings here
    
}

-(void) windowWillClose:(NSNotification *)notification {
    [NSApp stopModal];
}

@end
