//
//  BrightnessViewController.m
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/28/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import "BrightnessViewController.h"
#import "AppDelegate.h"

@interface BrightnessViewController ()

@end

@implementation BrightnessViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGDirectDisplayID currentDisplayId = [NSScreen.mainScreen.deviceDescription [@"NSScreenNumber"] unsignedIntValue];
    if (! CGDisplayIsBuiltin(currentDisplayId)) {
        uint loadedBrightness = 50;
        [AppDelegate loadSavedBrightness:&loadedBrightness forDisplayID:currentDisplayId];
        self.sliderBrightness.integerValue = loadedBrightness;
        self.sliderBrightness.maxValue = APP_DELEGATE.maxBrightness;
        lastBrightnessValue = loadedBrightness;
    }
}

- (IBAction)changeBrightness:(NSSlider *)sender {
    if (lastBrightnessValue != self.sliderBrightness.intValue) {
        lastBrightnessValue = (int)self.sliderBrightness.intValue;
        [AppDelegate changeMainScreenBrightness:lastBrightnessValue];
    }
}


@end
