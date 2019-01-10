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

#pragma mark - Key codes of special keys

// Extract from Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h
/* keycodes for keys that are independent of keyboard layout*/
enum {
    kVK_F17                       = 0x40,
    kVK_VolumeUp                  = 0x48,
    kVK_VolumeDown                = 0x49,
    kVK_Mute                      = 0x4A,
    kVK_F18                       = 0x4F,
    kVK_F19                       = 0x50,
    kVK_F20                       = 0x5A,
    kVK_F5                        = 0x60,
    kVK_F6                        = 0x61,
    kVK_F7                        = 0x62,
    kVK_F3                        = 0x63,
    kVK_F8                        = 0x64,
    kVK_F9                        = 0x65,
    kVK_F11                       = 0x67,
    kVK_F13                       = 0x69,
    kVK_F16                       = 0x6A,
    kVK_F14                       = 0x6B,
    kVK_F10                       = 0x6D,
    kVK_F12                       = 0x6F,
    kVK_F15                       = 0x71,
    kVK_Help                      = 0x72,
    kVK_Home                      = 0x73,
    kVK_PageUp                    = 0x74,
    kVK_ForwardDelete             = 0x75,
    kVK_F4                        = 0x76,
    kVK_End                       = 0x77,
    kVK_F2                        = 0x78,
    kVK_PageDown                  = 0x79,
    kVK_F1                        = 0x7A,
    kVK_LeftArrow                 = 0x7B,
    kVK_RightArrow                = 0x7C,
    kVK_DownArrow                 = 0x7D,
    kVK_UpArrow                   = 0x7E
};

#pragma mark - constants

static NSString *const kDisplaysBrightnessDefaultsKey = @"displays-brightness";
static const int brightnessStepsCount = 16;
static const int brightnessSubstepsPerStep = 4;
static const int brightnessSubstepsCount = brightnessStepsCount * brightnessSubstepsPerStep;

#pragma mark - variables

static void *(*_BSDoGraphicWithMeterAndTimeout)(CGDirectDisplayID arg0, BSGraphic arg1, int arg2, float v, int timeout) = NULL;

#pragma mark - functions

static BOOL set_control(CGDirectDisplayID display_id, uint control_id, uint new_value)
{
    struct DDCWriteCommand command;
    command.control_id = control_id;
    command.new_value = new_value;
    
    BOOL isCommandOk = DDCWrite(display_id, &command);
    
    if (! isCommandOk){
        NSLog(@"E: Failed to send DDCWrite command to display %u!", display_id);
    }
    
    return isCommandOk;
}

static BOOL get_control(CGDirectDisplayID display_id, uint control_id, uint* current_value, uint* max_value)
{
    struct DDCReadCommand command = {.control_id = control_id, .max_value = 0, .current_value = 0 };
    BOOL isCommandOk = DDCRead(display_id, &command);
    
    if (isCommandOk) {
        if (current_value != nil) {
            *current_value = command.current_value;
        }
        
        if (max_value != nil) {
            *max_value = command.max_value;
        }
    }
    else {
        NSLog(@"E: Failed to send DDCRead command to display %u!", display_id);
    }
    return isCommandOk;
}

static CGEventRef keyboardCGEventCallback(CGEventTapProxy proxy,
                             CGEventType type,
                             CGEventRef event,
                             void *refcon)
{
    //Surpress the F1/F2 key events to prevent other applications from catching it or playing beep sound
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

static void showBrightnessLevelPaneOnDisplay (uint brightnessLevelInSubsteps, CGDirectDisplayID displayId)
{
    if (_BSDoGraphicWithMeterAndTimeout != NULL)
    {
        // El Capitan and probably older systems
        _BSDoGraphicWithMeterAndTimeout(displayId, BSGraphicBacklightMeter, 0x0, (float)brightnessLevelInSubsteps/(float)brightnessSubstepsCount, 1);
    }
    else {
        // Sierra+
        [[NSClassFromString(@"OSDManager") sharedManager] showImage:OSDGraphicBacklight onDisplayID:displayId priority:OSDPriorityDefault msecUntilFade:1000 filledChiclets:(float)brightnessLevelInSubsteps totalChiclets:brightnessSubstepsCount locked:NO];
    }
    
}


#pragma mark - AppDelegate

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (strong, nonatomic) dispatch_source_t signalHandlerSource;
@end

@implementation AppDelegate

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

- (void)_registerGlobalKeyboardEvents
{
    [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *_Nonnull event) {
        if (event.type == NSEventTypeKeyDown)
        {
            BOOL isOptionModifierPressed = (event.modifierFlags & NSAlternateKeyMask) != 0;
            BOOL isShiftModifierPressed = (event.modifierFlags & NSShiftKeyMask) != 0;
        
            if ((event.keyCode == kVK_F1) ||  (event.keyCode == kVK_F2))
            {
                // Screen brightness adjustment
                int brightnessDelta = isOptionModifierPressed ? 1 : brightnessSubstepsPerStep;
                if (event.keyCode == kVK_F1) {
                    // F1 = decrease broghtness
                    brightnessDelta = -brightnessDelta;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self incrementScreenBrightnessWithStep: brightnessDelta inAllScreens:isShiftModifierPressed];
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    if (![self _loadBezelServices])
    {
        [self _loadOSDFramework];
    }
    [self _configureLoginItem];
    [self _registerSignalHandling];
    
    // If the process is trusted, register for keyboard events; otherwise wait for the user to declare the process trusted
    if (AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @true})) {
        [self _registerGlobalKeyboardEvents];
    }
    else {
        [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(startMonitoringKeysIfProcessTrusted:) userInfo:nil repeats:YES];
    }
}

- (void) startMonitoringKeysIfProcessTrusted:(NSTimer*)timer
{
    // Check if the process is trusted without prompting the user again
    if (AXIsProcessTrustedWithOptions(nil)) {
        [self _registerGlobalKeyboardEvents];
        [timer invalidate];
    }
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

}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication*) sender
{
    return NO;
}

- (void)incrementScreenBrightnessWithStep:(int)deltaInSubsteps inAllScreens:(BOOL)updateAllScreens
{
    if (! updateAllScreens) {
        // Set the brightness only in the main screen
        [self incrementScreenBrightnessWithStep:deltaInSubsteps inScreen:NSScreen.mainScreen];
    }
    else {
        for (NSScreen* screen in NSScreen.screens) {
            [self incrementScreenBrightnessWithStep:deltaInSubsteps inScreen:screen];
        }
    }
}

- (void) incrementScreenBrightnessWithStep:(int)deltaInSubsteps inScreen:(NSScreen*)targetScreen
{
    CGDirectDisplayID currentDisplayId = [targetScreen.deviceDescription [@"NSScreenNumber"] unsignedIntValue];
    
    BOOL isBuiltinDisplay = CGDisplayIsBuiltin(currentDisplayId);
    io_service_t builtinDisplayIOService = isBuiltinDisplay ? CGDisplayIOServicePort(currentDisplayId) : IO_OBJECT_NULL;
    
    BOOL isCurrentBrighnessAvailableFromExternalDisplay = NO;
    uint maxExternalDisplayBrightness = 100;
    NSString* currentExternalDisplayDefaultsKey;
    
    // Get the current brightness
    int currentBrightnessInSubsteps = -1;
    
    if (! isBuiltinDisplay) {
        
        uint currentBrightness = 50;
        
        // Get the current display brightness
        // Fist, try user defaults to avoid waiting for a timeout if the display is known not to support DDCRead;
        // If user defaults are not set, read the brightness value from the display
        
        BOOL isCurrentBrighnessReadFromDefaults = NO;
        currentExternalDisplayDefaultsKey = [NSString stringWithFormat:@"%u", currentDisplayId];
        NSDictionary* savedDisplayBrighnesses =  [NSUserDefaults.standardUserDefaults objectForKey:kDisplaysBrightnessDefaultsKey];
        if ([savedDisplayBrighnesses isKindOfClass:[NSDictionary class]]) {
            NSNumber* savedCurrentBrightness = savedDisplayBrighnesses [currentExternalDisplayDefaultsKey];
            if ([savedCurrentBrightness isKindOfClass:[NSNumber class]]) {
                currentBrightness = (uint) savedCurrentBrightness.unsignedIntegerValue;
                isCurrentBrighnessReadFromDefaults = YES;
            }
        }
        
        if (! isCurrentBrighnessReadFromDefaults) {
            isCurrentBrighnessAvailableFromExternalDisplay = get_control(currentDisplayId, BRIGHTNESS, &currentBrightness, &maxExternalDisplayBrightness);
        }

        currentBrightnessInSubsteps = round((double)currentBrightness / (double)maxExternalDisplayBrightness * (double)brightnessSubstepsCount);
    }
    else {
        float currentBrightness; 
        IOReturn ioResult = IODisplayGetFloatParameter(builtinDisplayIOService, kNilOptions, CFSTR(kIODisplayBrightnessKey), &currentBrightness);
        if (ioResult == kIOReturnSuccess) {
            // currentBrightness is in the [0, 1] range: convert it to substeps
            currentBrightnessInSubsteps = round((double)currentBrightness * (double)brightnessSubstepsCount);
        }
    }
    
    if (currentBrightnessInSubsteps != -1) {
        
        // Compute the new brightness for this display
        int newBrightnessInSubsteps = MIN(MAX(0, currentBrightnessInSubsteps + deltaInSubsteps), brightnessSubstepsCount);
        if (abs(deltaInSubsteps) != 1) {
            // newBrightnessInSubsteps must be a multiple of deltaInSubsteps
            newBrightnessInSubsteps = (newBrightnessInSubsteps / deltaInSubsteps) * deltaInSubsteps;
        }
        
        if (newBrightnessInSubsteps != currentBrightnessInSubsteps) {
            // Set the new brightness
            if (! isBuiltinDisplay) {
                uint newBrightness = (uint) round((double)newBrightnessInSubsteps / (double)brightnessSubstepsCount * (double)maxExternalDisplayBrightness);
                
                if (set_control(currentDisplayId, BRIGHTNESS, newBrightness)) {
                
                    // NSLog(@"New brightness: %d", newBrightness);
                    
                    if  (! isCurrentBrighnessAvailableFromExternalDisplay) {
                        // Save the new brighness value
                        NSMutableDictionary* newDisplayBrighnesses;
                        NSDictionary* savedDisplayBrighnesses =  [NSUserDefaults.standardUserDefaults objectForKey:kDisplaysBrightnessDefaultsKey];
                        
                        if ([savedDisplayBrighnesses isKindOfClass:[NSDictionary class]]) {
                            newDisplayBrighnesses = [NSMutableDictionary dictionaryWithDictionary:savedDisplayBrighnesses];
                        }                    
                        else {
                            newDisplayBrighnesses = [NSMutableDictionary new];
                        }
                        
                        newDisplayBrighnesses [currentExternalDisplayDefaultsKey] = @(newBrightness);
                        
                        [NSUserDefaults.standardUserDefaults setObject:newDisplayBrighnesses forKey:kDisplaysBrightnessDefaultsKey];
                    }
                }
                else {
                    // Brightness has not been set
                    newBrightnessInSubsteps = currentBrightnessInSubsteps;
                }
            }
            else { 
                // Builtin display
                float newBrightness = (double)newBrightnessInSubsteps / (double)brightnessSubstepsCount;
                IOReturn ioResult = IODisplaySetFloatParameter(builtinDisplayIOService, kNilOptions,  CFSTR(kIODisplayBrightnessKey), newBrightness);
                if (ioResult != kIOReturnSuccess) {
                    // Brightness has not been set
                    newBrightnessInSubsteps = currentBrightnessInSubsteps;
                }
            }
        }
        
        // Display the brighness level OSD
        showBrightnessLevelPaneOnDisplay(newBrightnessInSubsteps, currentDisplayId);
    }
}

@end
