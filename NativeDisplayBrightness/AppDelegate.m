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
#import "SettingsWindowController.h"
#import "BrightnessViewController.h"

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
        if (keyCode == BRIGHTNESS_UP_KEY || keyCode == BRIGHTNESS_DOWN_KEY)
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
        [[NSClassFromString(@"OSDManager") sharedManager] showImage:OSDGraphicBacklight
                                                        onDisplayID:displayId priority:OSDPriorityDefault
                                                      msecUntilFade:1000
                                                     filledChiclets:(float)brightnessLevelInSubsteps
                                                      totalChiclets:brightnessSubstepsCount
                                                             locked:NO];
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
        
            if ((event.keyCode == BRIGHTNESS_DOWN_KEY) ||  (event.keyCode == BRIGHTNESS_UP_KEY))
            {
                // Screen brightness adjustment
                int brightnessDelta = isOptionModifierPressed ? 1 : brightnessSubstepsPerStep;
                if (event.keyCode == BRIGHTNESS_DOWN_KEY) {
                    // F1 = decrease brightness
                    brightnessDelta = -brightnessDelta;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [AppDelegate changeMainScreenBrightnessWithStep: brightnessDelta];
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
    
    //Status Bar Icon
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    self.statusBarIcon = [bar statusItemWithLength:STATUS_ICON_WIDTH_TEXT];
    
    NSImage *icon = [NSImage imageNamed:@"icon"];
    icon.template = YES;
    self.statusBarIcon.image = icon;
    self.statusBarIcon.highlightMode = YES;
    
    CGDirectDisplayID currentDisplayId = [NSScreen.mainScreen.deviceDescription [@"NSScreenNumber"] unsignedIntValue];
    if (! CGDisplayIsBuiltin(currentDisplayId)) {
        uint loadedBrightness = 50;
        [AppDelegate loadSavedBrightness:&loadedBrightness forDisplayID:currentDisplayId];
        self.statusBarIcon.title = [NSString stringWithFormat:@"%d%%",loadedBrightness];
    }
    
    //Status Bar Menu:
    self.statusBarMenu = [[NSMenu alloc] init];
    
    //Brightness
    NSMenuItem *brightness = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.brightnessView = [[BrightnessViewController alloc] initWithNibName:@"BrightnessViewController" bundle:nil];
    [brightness setView:self.brightnessView.view];
    [self.statusBarMenu addItem:brightness];
    
    [self.statusBarMenu addItem: [NSMenuItem separatorItem]];
    
    //Settings
    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"Settings..."
                                                  action:@selector(showSettings)
                                           keyEquivalent:@""];
    settings.target = self;
    [self.statusBarMenu addItem:settings];
    
    //Quit
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                    action:@selector(quitApp)
                                             keyEquivalent:@""];
    quit.target = self;
    [self.statusBarMenu addItem:quit];
    
    
    
    self.statusBarIcon.menu = self.statusBarMenu;
    
    
    // If the process is trusted, register for keyboard events; otherwise wait for the user to declare the process trusted
    if (AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @true})) {
        [self _registerGlobalKeyboardEvents];
    }
    else {
        [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(startMonitoringKeysIfProcessTrusted:) userInfo:nil repeats:YES];
    }
}

-(void)showSettings {
    SettingsWindowController *settings = [[SettingsWindowController alloc] initWithWindowNibName:@"SettingsWindowController"];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp runModalForWindow:settings.window];
}

-(void)quitApp {
    [NSApp terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication*) sender
{
    return NO;
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

+(void)saveBrightness:(int) newBrightness  forDisplayID:(CGDirectDisplayID) displayID  {
    NSMutableDictionary* newDisplayBrighnesses;
    NSDictionary* savedDisplayBrighnesses = [NSUserDefaults.standardUserDefaults objectForKey:kDisplaysBrightnessDefaultsKey];
    
    if ([savedDisplayBrighnesses isKindOfClass:[NSDictionary class]]) {
        newDisplayBrighnesses = [NSMutableDictionary dictionaryWithDictionary:savedDisplayBrighnesses];
    } else {
        newDisplayBrighnesses = [NSMutableDictionary new];
    }
    NSString* currentDisplayIdKey = [NSString stringWithFormat:@"%u", displayID];
    newDisplayBrighnesses [currentDisplayIdKey] = @(newBrightness);
    
    [NSUserDefaults.standardUserDefaults setObject:newDisplayBrighnesses forKey:kDisplaysBrightnessDefaultsKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    APP_DELEGATE.currentBrightness = newBrightness;
}

+(BOOL)loadSavedBrightness:(uint*) savedBrightness forDisplayID:(CGDirectDisplayID) displayID {
    
    NSString* currentDisplayIdKey = [NSString stringWithFormat:@"%u", displayID];
    NSDictionary* savedDisplayBrighnesses = [NSUserDefaults.standardUserDefaults objectForKey:kDisplaysBrightnessDefaultsKey];
    if ([savedDisplayBrighnesses isKindOfClass:[NSDictionary class]]) {
        NSNumber* savedCurrentBrightness = savedDisplayBrighnesses [currentDisplayIdKey];
        if ([savedCurrentBrightness isKindOfClass:[NSNumber class]]) {
            uint currentBrightness = (uint)savedCurrentBrightness.unsignedIntegerValue;
            *savedBrightness = currentBrightness;
            APP_DELEGATE.currentBrightness = currentBrightness;
            return YES;
        }
    }
    return NO;
}

+(void)changeMainScreenBrightnessWithStep:(int) deltaInSubsteps {
    
    CGDirectDisplayID currentDisplayId = [NSScreen.mainScreen.deviceDescription [@"NSScreenNumber"] unsignedIntValue];
    NSString* currentDisplayIdKey = [NSString stringWithFormat:@"%u", currentDisplayId];
    if (! CGDisplayIsBuiltin(currentDisplayId)) {
        
        uint currentBrightness = 50;
        uint maxBrightness = 100;
        
        // Get the current display brightness
        // Fist, try user defaults to avoid waiting for a timeout if the display is known not to support DDCRead;
        // If user defaults are not set, read the brightness value from the display
        
        BOOL isCurrentBrighnessReadFromDefaults = [AppDelegate loadSavedBrightness:&currentBrightness forDisplayID:currentDisplayId];
        BOOL isCurrentBrighnessAvailableFromDisplay = NO;
        if (! isCurrentBrighnessReadFromDefaults) {
            isCurrentBrighnessAvailableFromDisplay = get_control(currentDisplayId, BRIGHTNESS, &currentBrightness, &maxBrightness);
        }

        int currentBrightnessInSubsteps = round((double)currentBrightness / (double)maxBrightness * (double)brightnessSubstepsCount);
        
        int newBrightnessInSubsteps = MIN(MAX(0, currentBrightnessInSubsteps + deltaInSubsteps), brightnessSubstepsCount);
        if (abs(deltaInSubsteps) != 1) {
            // newBrightnessInSubsteps must be a multiple of deltaInSubsteps
            newBrightnessInSubsteps = (newBrightnessInSubsteps / deltaInSubsteps) * deltaInSubsteps;
        }
        
        uint newBrightness = (uint) round((double)newBrightnessInSubsteps / (double)brightnessSubstepsCount * (double)maxBrightness);
        
        if (newBrightness != currentBrightness) {
           
            if (set_control(currentDisplayId, BRIGHTNESS, newBrightness)) {
                
                //NSLog(@"New brightness: %d", newBrightness);
                
                APP_DELEGATE.statusBarIcon.title = [NSString stringWithFormat:@"%i%%",newBrightness];
                // Display the brighness level OSD
                showBrightnessLevelPaneOnDisplay(newBrightnessInSubsteps, currentDisplayId);
                
                //if  (! isCurrentBrighnessAvailableFromDisplay) {
                    // Save the new brighness value
                    NSMutableDictionary* newDisplayBrighnesses;
                    NSDictionary* savedDisplayBrighnesses = [NSUserDefaults.standardUserDefaults objectForKey:kDisplaysBrightnessDefaultsKey];
                    
                    if ([savedDisplayBrighnesses isKindOfClass:[NSDictionary class]]) {
                        newDisplayBrighnesses = [NSMutableDictionary dictionaryWithDictionary:savedDisplayBrighnesses];
                    } else {
                        newDisplayBrighnesses = [NSMutableDictionary new];
                    }
                    
                    newDisplayBrighnesses [currentDisplayIdKey] = @(newBrightness);
                    
                    [NSUserDefaults.standardUserDefaults setObject:newDisplayBrighnesses forKey:kDisplaysBrightnessDefaultsKey];
                    [NSUserDefaults.standardUserDefaults synchronize];
                //}
            }
        }
        else {
            // Min or max brightness level: present the OSD to provide a feedback to the user, but don't send a command
            showBrightnessLevelPaneOnDisplay(newBrightness, currentDisplayId);
        }
    }
}

+(void)changeMainScreenBrightness:(int) newBrightness {
    
    CGDirectDisplayID currentDisplayId = [NSScreen.mainScreen.deviceDescription [@"NSScreenNumber"] unsignedIntValue];
    if (! CGDisplayIsBuiltin(currentDisplayId)) {
        if (set_control(currentDisplayId, BRIGHTNESS, newBrightness)) {
            APP_DELEGATE.statusBarIcon.title = [NSString stringWithFormat:@"%i%%",newBrightness];
            [AppDelegate saveBrightness:newBrightness forDisplayID:currentDisplayId];
        }
    }
}

@end
