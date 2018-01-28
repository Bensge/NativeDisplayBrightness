//
//  BrightnessViewController.h
//  NativeDisplayBrightness
//
//  Created by Volodymyr Klymenko on 1/28/18.
//  Copyright © 2018 Volodymyr Klymenko. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BrightnessViewController : NSViewController {
    int lastBrightnessValue;
}

@property (weak) IBOutlet NSSlider *sliderBrightness;
- (IBAction)changeBrightness:(NSSlider *)sender;

@end
