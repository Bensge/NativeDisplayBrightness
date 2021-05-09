//
//  AppDelegate.m
//  NativeDisplayBrightness
//
//  Created by Benno Krauss on 19.10.16.
//  Copyright © 2016 Benno Krauss. All rights reserved.
//
//  Updated by Ivan_Alone on 09.05.21
//  Made with GNU GPL v3 permission
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
ButtonControl *globalButtonBrightnessUp = NULL, *globalButtonBrightnessDown = NULL;
NSDictionary* keyCodesAll = NULL;

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
    //Surpress the F1/F2 key events to prevent other applications from catching it or playing beep sound
    if (type == NX_KEYDOWN || type == NX_KEYUP || type == NX_FLAGSCHANGED)
    {
        int64_t keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        int64_t modifierFlags = CGEventGetFlags(event);
        
        if ([globalButtonBrightnessDown verifyKey:keyCode arg2: modifierFlags] || [globalButtonBrightnessUp verifyKey:keyCode arg2: modifierFlags])
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
@property (strong, nonatomic) dispatch_source_t signalHandlerSource;
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
        if ([globalButtonBrightnessDown verifyKey:event.keyCode arg2: event.modifierFlags])
        {
            if (event.type == NSEventTypeKeyDown)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self decreaseBrightness];
                });
            }
        }
        else if ([globalButtonBrightnessUp verifyKey:event.keyCode arg2: event.modifierFlags])
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
    CGEventMask interestedEvents = NX_KEYDOWNMASK | NX_KEYUPMASK | NX_FLAGSCHANGEDMASK;
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
    [self loadSettings];
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

void shutdownSignalHandler(int signal)
{
    //Don't do anything
}

- (void)_registerSignalHandling
{
    //Register signal callback that will gracefully shut the application down
    self.signalHandlerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(self.signalHandlerSource, ^{
        NSLog(@"Caught SIGTERM");
        [[NSApplication sharedApplication] terminate:self];
    });
    dispatch_resume(self.signalHandlerSource);
    //Register signal handler that will prevent the app from being killed
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

- (int) parseKeyCode: (NSString*) candidate {
    if (keyCodesAll == NULL) {
        keyCodesAll = [self JSONFromFile:@"macOSKeyCodes"];
    }
    
    candidate = candidate.uppercaseString;
    
    if (candidate.length < 3 || ![[candidate substringToIndex: 3] isEqualToString:@"VK_"] ) {
        candidate = [NSString stringWithFormat:@"%@%@", @"VK_", candidate];
    }
    
    if (keyCodesAll != NULL && keyCodesAll[candidate]) {
        return [[keyCodesAll valueForKey:candidate] intValue ];
    }
    
    return 0;
}

- (ButtonControl*) parseButtonData: (NSDictionary*) jsonButton {
    ButtonControl* btn = [ButtonControl new];
    
    NSString* keyCode = [jsonButton objectForKey:@"keyCode"];
    
    if (keyCode != NULL) {
        int keyCodeInt = keyCode.intValue;
        NSString* recomp = [NSString stringWithFormat:@"%d", keyCodeInt];
        
        if (keyCode != recomp) {
            keyCodeInt = [self parseKeyCode: keyCode];
        }
        
        btn.keyCode = keyCodeInt;
        
        btn.isShift = [[jsonButton valueForKey:@"isShift"] boolValue];
        btn.isAlt   = [[jsonButton valueForKey:@"isAlt"  ] boolValue];
        btn.isCmd   = [[jsonButton valueForKey:@"isCmd"  ] boolValue];
        btn.isCtrl  = [[jsonButton valueForKey:@"isCtrl" ] boolValue];
        btn.isCaps  = [[jsonButton valueForKey:@"isCaps" ] boolValue];
        btn.isFN    = [[jsonButton valueForKey:@"isFN"   ] boolValue];
        
        return btn;
    }
    return NULL;
}

- (void)loadSettings
{
    NSDictionary *dict = [self JSONFromFile: @"config"];

    NSDictionary* buttonBrightnessUp   = [dict objectForKey:@"buttonBrightnessUp"];
    NSDictionary* buttonBrightnessDown = [dict objectForKey:@"buttonBrightnessDown"];
    
    globalButtonBrightnessUp           = [ButtonControl new];
    globalButtonBrightnessUp.keyCode   = kVK_F2;
    
    globalButtonBrightnessDown         = [ButtonControl new];
    globalButtonBrightnessDown.keyCode = kVK_F1;
    
    if (buttonBrightnessUp != NULL) {
        ButtonControl* btn = [self parseButtonData: buttonBrightnessUp];
        
        if (btn && btn.keyCode) {
            globalButtonBrightnessUp = btn;
        }
    }
    
    if (buttonBrightnessDown != NULL) {
        ButtonControl* btn = [self parseButtonData: buttonBrightnessDown];
        
        if (btn && btn.keyCode) {
            globalButtonBrightnessDown = btn;
        }
    }
    
    NSLog(@"Config loaded!");
}

- (NSDictionary *)JSONFromFile: (NSString*) filename
{
    NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
}

@end
