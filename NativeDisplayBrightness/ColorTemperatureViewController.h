//
//  ColorTemperatureViewController.h
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/29/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ColorTemperatureViewController : NSViewController

@property (weak) IBOutlet NSButton *adjustColorTemperature;
@property (weak) IBOutlet NSSlider *sliderColorTemperature;

@end
