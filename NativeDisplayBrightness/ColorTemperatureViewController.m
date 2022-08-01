//
//  ColorTemperatureViewController.m
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/29/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import "ColorTemperatureViewController.h"
#import "Config.h"

@interface ColorTemperatureViewController ()

@end

@implementation ColorTemperatureViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    StatusData status;
    [APP_DELEGATE.blueLight getBlueLightStatus:&status];
    if (status.enabled) {
        self.adjustColorTemperature.state = NSOnState;
    } else {
        self.adjustColorTemperature.state = NSOffState;
        self.sliderColorTemperature.enabled = NO;
    }
    self.sliderColorTemperature.maxValue = APP_DELEGATE.colorTemperatureLimit;
}

- (IBAction)enableColorTemperature:(NSButton *)sender {
    [APP_DELEGATE.blueLight setEnabled:sender.state];
    self.sliderColorTemperature.enabled = sender.state;
}

- (IBAction)changeColorTemperature:(NSSlider *)sender {
    [AppDelegate changeScreenColorTemperature:sender.floatValue];
}


@end
