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
    self.adjustColorTemperature.state = APP_DELEGATE.adjustColorTemperature;
    self.sliderColorTemperature.maxValue = APP_DELEGATE.colorTemperatureLimit;
}

- (IBAction)adjustColorTemperature:(NSButton *)sender {
    APP_DELEGATE.adjustColorTemperature = sender.state;
}


- (IBAction)changeColorTemperature:(NSSlider *)sender {
    [AppDelegate changeScreenColorTemperature:sender.floatValue];
}


@end
