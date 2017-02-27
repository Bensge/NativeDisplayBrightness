//
//  AppDelegate.m
//  NativeDisplayBrightness
//
//  Created by Benno Krauss on 19.10.16.
//  Copyright © 2016 Benno Krauss. All rights reserved.
//

#import "AppDelegate.h"
#import "DDC.h"
#import "BezelServices.h"
#import "OSD.h"
#include <dlfcn.h>
@import Carbon;

#pragma mark - constants

static NSString *brightnessValuePreferenceKey = @"brightness";
static const float brightnessStep = 100/16.f;

#pragma mark - variables

void *(*_BSDoGraphicWithMeterAndTimeout)(CGDirectDisplayID arg0, BSGraphic arg1, int arg2, float v, int timeout) = NULL;

#pragma mark - functions

void set_control(CGDirectDisplayID cdisplay, uint control_id, uint new_value)
{
    struct DDCWriteCommand command;
    command.control_id = control_id;
    command.new_value = new_value;
    
    if (!DDCWrite(cdisplay, &command)){
        NSLog(@"E: Failed to send DDC command!");
    }
}


CGEventRef keyboardCGEventCallback(CGEventTapProxy proxy,
                             CGEventType type,
                             CGEventRef event,
                             void *refcon)
{
    //Surpress the brightness key events to prevent other applications from catching it
    if (type == NX_KEYDOWN || type == NX_KEYUP || type == NX_FLAGSCHANGED)
    {
        int64_t keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        if (keyCode == kVK_F2 || keyCode == kVK_F1)
        {
            return NULL;
        }
    }
    return event;
}

#pragma mark - AppDelegate

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic) float brightness;
@end

@implementation AppDelegate
@synthesize brightness=_brightness;

- (BOOL)_loadBezelServices
{
    // Load BezelServices framework
    void *handle = dlopen("/System/Library/PrivateFrameworks/BezelServices.framework/Versions/A/BezelServices", RTLD_GLOBAL);
    if (!handle) {
        NSLog(@"Error opening framework");
        return NO;
    }
    else {
        _BSDoGraphicWithMeterAndTimeout = dlsym(handle, "BSDoGraphicWithMeterAndTimeout");
        return _BSDoGraphicWithMeterAndTimeout != NULL;
    }
}

- (BOOL)_loadOSDFramework
{
    return [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/OSD.framework"] load];
}

- (void)_configureLoginItem
{
    NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    LSSharedFileListRef loginItemsListRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    NSDictionary *properties = @{@"com.apple.loginitem.HideOnLaunch": @YES};
    LSSharedFileListInsertItemURL(loginItemsListRef, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)bundleURL, (__bridge CFDictionaryRef)properties,NULL);
}

- (void)_checkTrusted
{
    BOOL isTrusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @true});
    NSLog(@"istrusted: %i",isTrusted);
}

- (void)_registerGlobalKeyboardEvents
{
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown | NSEventMaskKeyUp handler:^(NSEvent *_Nonnull event) {
        //NSLog(@"event!!");
        if (event.keyCode == kVK_F1)
        {
            if (event.type == NSEventTypeKeyDown)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self decreaseBrightness];
                });
            }
        }
        else if (event.keyCode == kVK_F2)
        {
            if (event.type == NSEventTypeKeyDown)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self increaseBrightness];
                });
            }
        }
    }];
    
    CFRunLoopRef runloop = (CFRunLoopRef)CFRunLoopGetCurrent();
    
    CGEventMask interestedEvents = kCGEventKeyDown | NSKeyUp;
    CFMachPortRef eventTap = CGEventTapCreate(kCGAnnotatedSessionEventTap, kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault, interestedEvents, keyboardCGEventCallback, (__bridge void * _Nullable)(self));
    // by passing self as last argument, you can later send events to this class instance
    
    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault,
                                                              eventTap, 0);
    CFRunLoopAddSource((CFRunLoopRef)runloop, source, kCFRunLoopCommonModes);
    
    CGEventTapEnable(eventTap, true);
}

- (void)_saveBrightness
{
    [[NSUserDefaults standardUserDefaults] setFloat:self.brightness forKey:brightnessValuePreferenceKey];
}

- (void)_loadBrightness
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        brightnessValuePreferenceKey: @(8*brightnessStep)
    }];
    
    _brightness = [[NSUserDefaults standardUserDefaults] floatForKey:brightnessValuePreferenceKey];
    NSLog(@"Loaded value: %f",_brightness);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    delegateInstance = self;
    if (![self _loadBezelServices])
    {
        [self _loadOSDFramework];
    }
    [self _configureLoginItem];
    [self _checkTrusted];
    [self _registerGlobalKeyboardEvents];
    [self _loadBrightness];
    [self _registerSignalHandling];
}

__weak AppDelegate *delegateInstance = nil;

void shutdownSignalHandler(int signal) {
    NSLog(@"Caught SIGTERM");
    [delegateInstance _willTerminate];
}

- (void)_registerSignalHandling
{
    signal(SIGTERM, shutdownSignalHandler);
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self _willTerminate];
}

- (void)_willTerminate
{
    NSLog(@"willTerminate");
    [self _saveBrightness];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication*) sender
{
    return NO;
}

- (void)setBrightness:(float)value
{
    _brightness = value;
    
    CGDirectDisplayID display = CGSMainDisplayID();
    
    if (_BSDoGraphicWithMeterAndTimeout != NULL)
    {
        // El Capitan and probably older systems
        _BSDoGraphicWithMeterAndTimeout(display, BSGraphicBacklightMeter, 0x0, value/100.f, 1);
    }
    else {
        // Sierra+
        [[NSClassFromString(@"OSDManager") sharedManager] showImage:OSDGraphicBacklight onDisplayID:CGSMainDisplayID() priority:OSDPriorityDefault msecUntilFade:1000 filledChiclets:value/brightnessStep totalChiclets:100.f/brightnessStep locked:NO];
    }
    
    for (NSScreen *screen in NSScreen.screens) {
        NSDictionary *description = [screen deviceDescription];
        if ([description objectForKey:@"NSDeviceIsScreen"]) {
            CGDirectDisplayID screenNumber = [[description objectForKey:@"NSScreenNumber"] unsignedIntValue];
            
            set_control(screenNumber, BRIGHTNESS, value);
        }
    }
}

- (float)brightness
{
    return _brightness;
}

- (void)increaseBrightness
{
    self.brightness = MIN(self.brightness+brightnessStep,100);
}

- (void)decreaseBrightness
{
    self.brightness = MAX(self.brightness-brightnessStep,0);
}


@end
