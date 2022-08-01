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
#import "ColorTemperatureViewController.h"

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
        if (keyCode == [[APP_DELEGATE.keys valueForKey:APP_DELEGATE.increaseBrightnessKey] unsignedShortValue] ||
            keyCode == [[APP_DELEGATE.keys valueForKey:APP_DELEGATE.decreaseBrightnessKey] unsignedShortValue] ||
            keyCode == [[APP_DELEGATE.keys valueForKey:APP_DELEGATE.colorTemperatureLessWarmKey] unsignedShortValue] ||
            keyCode == [[APP_DELEGATE.keys valueForKey:APP_DELEGATE.colorTemperatureMoreWarmKey] unsignedShortValue])
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
            BOOL isOptionModifierPressed = (event.modifierFlags & NSAlternateKeyMask) != 0 || self.smoothStep;
            
            if ((event.keyCode == [[self.keys valueForKey:self.decreaseBrightnessKey] unsignedShortValue]) ||
                (event.keyCode == [[self.keys valueForKey:self.increaseBrightnessKey] unsignedShortValue]))
            {
                // Screen brightness adjustment
                int brightnessDelta = isOptionModifierPressed ? 1 : brightnessSubstepsPerStep;
                if (event.keyCode == [[self.keys valueForKey:self.decreaseBrightnessKey] unsignedShortValue]) {
                    // default F1 = decrease brightness
                    brightnessDelta = -brightnessDelta;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [AppDelegate changeMainScreenBrightnessWithStep: brightnessDelta];
                });
            }
            
            if (event.keyCode == [[self.keys valueForKey:self.colorTemperatureLessWarmKey] unsignedShortValue] ||
                event.keyCode == [[self.keys valueForKey:self.colorTemperatureMoreWarmKey] unsignedShortValue]) {
                float valueStep = COLOR_TEMPERATURE_STEP;
                valueStep = (event.keyCode == [[self.keys valueForKey:self.colorTemperatureLessWarmKey] unsignedShortValue]) ? -valueStep : valueStep;
                [AppDelegate changeScreenColorTemperatureStep:valueStep];
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
    
//DEBUG: clean user settings if needed
//    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
//    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
//    [NSApp terminate:0];
    
    self.keys = @{
                  @"F1"  : @0x7A,
                  @"F2"  : @0x78,
                  @"F3"  : @0x63,
                  @"F4"  : @0x76,
                  @"F5"  : @0x60,
                  @"F6"  : @0x61,
                  @"F7"  : @0x62,
                  @"F8"  : @0x64,
                  @"F9"  : @0x65,
                  @"F10" : @0x6D,
                  @"F11" : @0x67,
                  @"F12" : @0x6F,
                  @"F13" : @0x69,
                  @"F14" : @0x6B,
                  @"F15" : @0x71,
                  @"F16" : @0x6A,
                  @"F17" : @0x40,
                  @"F18" : @0x4F,
                  @"F19" : @0x50,
                  @"F20" : @0x5A
                  };
    
    if (![self _loadBezelServices])
    {
        [self _loadOSDFramework];
    }
    [self _configureLoginItem];
    [self _registerSignalHandling];
    
    //Color Temperature
    self.blueLight = [[CBBlueLightClient alloc] init];
    self.supportsBlueLightReduction = [CBBlueLightClient supportsBlueLightReduction];
    
    //Status Bar Icon
    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    self.statusBarIcon = [bar statusItemWithLength:self.showBrightness ? STATUS_ICON_WIDTH_TEXT : STATUS_ICON_WIDTH];
    
    NSImage *icon = [NSImage imageNamed:@"icon"];
    icon.template = YES;
    self.statusBarIcon.image = icon;
    self.statusBarIcon.highlightMode = YES;
    
    CGDirectDisplayID currentDisplayId = [NSScreen.mainScreen.deviceDescription [@"NSScreenNumber"] unsignedIntValue];
    if (! CGDisplayIsBuiltin(currentDisplayId)) {
        uint loadedBrightness = 50;
        uint maxBrightness = 100;
        bool loadedFromSettings = [AppDelegate loadSavedBrightness:&loadedBrightness forDisplayID:currentDisplayId];
        if (!loadedFromSettings) {
            NSLog(@"Settings not loaded, use monitor value: %i",loadedBrightness);
            get_control(currentDisplayId, BRIGHTNESS, &loadedBrightness, &maxBrightness);
            [AppDelegate saveBrightness:loadedBrightness forDisplayID:currentDisplayId];
        }
        self.statusBarIcon.title = self.showBrightness ? [NSString stringWithFormat:@"%d%%",loadedBrightness] : @"";
    }
    
    //Status Bar Menu
    self.statusBarMenu = [[NSMenu alloc] init];
    
    //Brightness
    NSMenuItem *brightness = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.brightnessView = [[BrightnessViewController alloc] initWithNibName:@"BrightnessViewController" bundle:nil];
    [brightness setView:self.brightnessView.view];
    [self.statusBarMenu addItem:brightness];
    
    //Separator
    [self.statusBarMenu addItem: [NSMenuItem separatorItem]];
    
    //Color Temperature
    self.colorTemperatureMenu = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.colorTemperatureView = [[ColorTemperatureViewController alloc] initWithNibName:@"ColorTemperatureViewController" bundle:nil];
    [self.colorTemperatureMenu setView:self.colorTemperatureView.view];
    [self.statusBarMenu addItem:self.colorTemperatureMenu];
    
    //this for some reason not work..will just remove
    //self.colorTemperatureMenu.hidden = !APP_DELEGATE.adjustColorTemperature;
    
    if (!APP_DELEGATE.adjustColorTemperature) {
        [self.statusBarMenu removeItem:self.colorTemperatureMenu];
    } else {
        float curStrength;
        [self.blueLight getStrength:&curStrength];
        self.colorTemperatureView.sliderColorTemperature.floatValue = curStrength;
    }
    
    //Separator
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

//Settings
- (void)setMultiMonitor:(BOOL ) multiMonitor {
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:multiMonitor] forKey:@"multiMonitor"];
}

- (BOOL)multiMonitor {
    id multiMonitor = [NSUserDefaults.standardUserDefaults valueForKey:@"multiMonitor"];
    if (!multiMonitor) {
        return YES;
    }
    return [multiMonitor boolValue];
}

- (void)setSmoothStep:(BOOL ) smoothStep {
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:smoothStep] forKey:@"smoothStep"];
}

- (BOOL)smoothStep {
    id smoothStep = [NSUserDefaults.standardUserDefaults valueForKey:@"smoothStep"];
    if (!smoothStep) {
        return NO;
    }
    return [smoothStep boolValue];
}

- (void)setShowBrightness:(BOOL)showBrightness {
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:showBrightness] forKey:@"showBrightness"];
}

- (BOOL)showBrightness {
    id showBrightness = [NSUserDefaults.standardUserDefaults valueForKey:@"showBrightness"];
    if (!showBrightness) {
        return YES;
    }
    return [showBrightness boolValue];
}

- (void)setMaxBrightness:(int)maxBrightness {
    self.brightnessView.sliderBrightness.maxValue = maxBrightness;
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithInt:maxBrightness] forKey:@"maxBrightness"];
}

- (int)maxBrightness {
    id maxBrightness = [NSUserDefaults.standardUserDefaults valueForKey:@"maxBrightness"];
    if (!maxBrightness) {
        return 100;
    }
    return [maxBrightness intValue];
}

- (NSString *)decreaseBrightnessKey {
    id decreaseBrightnessKeyCode = [NSUserDefaults.standardUserDefaults valueForKey:@"decreaseBrightnessKey"];
    if (!decreaseBrightnessKeyCode) {
        return @"F1";
    }
    return decreaseBrightnessKeyCode;
}

- (void)setDecreaseBrightnessKey:(NSString *)decreaseBrightnessKeyCode {
    [NSUserDefaults.standardUserDefaults setObject:decreaseBrightnessKeyCode forKey:@"decreaseBrightnessKey"];
}

- (NSString *)increaseBrightnessKey {
    id increaseBrightnessKeyCode = [NSUserDefaults.standardUserDefaults valueForKey:@"increaseBrightnessKey"];
    if (!increaseBrightnessKeyCode) {
        return @"F2";
    }
    return increaseBrightnessKeyCode;
}

- (void)setIncreaseBrightnessKey:(NSString *)increaseBrightnessKeyCode {
    [NSUserDefaults.standardUserDefaults setObject:increaseBrightnessKeyCode forKey:@"increaseBrightnessKey"];
}

- (void)setAdjustColorTemperature:(BOOL)adjustColorTemperature {
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithBool:adjustColorTemperature] forKey:@"adjustColorTemperature"];
}

- (BOOL)adjustColorTemperature {
    id adjustColorTemperature = [NSUserDefaults.standardUserDefaults valueForKey:@"adjustColorTemperature"];
    if (!adjustColorTemperature) {
        return NO;
    }
    return [adjustColorTemperature boolValue];
}

- (float)colorTemperature {
    id colorTemperature = [NSUserDefaults.standardUserDefaults valueForKey:@"colorTemperature"];
    if (!colorTemperature) {
        return 0.0;
    }
    return [colorTemperature floatValue];
}

- (void)setColorTemperature:(float)colorTemperature {
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithFloat:self.colorTemperature] forKey:@"colorTemperature"];
}

- (void)setColorTemperatureLimit:(float)colorTemperatureLimit {
    self.colorTemperatureView.sliderColorTemperature.maxValue = colorTemperatureLimit;
    [NSUserDefaults.standardUserDefaults setObject:[NSNumber numberWithFloat:colorTemperatureLimit] forKey:@"colorTemperatureLimit"];
}

- (float)colorTemperatureLimit {
    id colorTemperatureLimit = [NSUserDefaults.standardUserDefaults valueForKey:@"colorTemperatureLimit"];
    if (!colorTemperatureLimit) {
        return 0.5;
    }
    return [colorTemperatureLimit floatValue];
}

- (NSString *)colorTemperatureLessWarmKey {
    id colorTemperatureLessWarmKeyCode = [NSUserDefaults.standardUserDefaults valueForKey:@"colorTemperatureLessWarmKey"];
    if (!colorTemperatureLessWarmKeyCode) {
        return @"F3";
    }
    return colorTemperatureLessWarmKeyCode;
}

- (void)setColorTemperatureLessWarmKey:(NSString *)colorTemperatureLessWarmKeyCode {
    [NSUserDefaults.standardUserDefaults setObject:colorTemperatureLessWarmKeyCode forKey:@"colorTemperatureLessWarmKey"];
}

- (NSString *)colorTemperatureMoreWarmKey {
    id colorTemperatureMoreWarmKeyCode = [NSUserDefaults.standardUserDefaults valueForKey:@"colorTemperatureMoreWarmKey"];
    if (!colorTemperatureMoreWarmKeyCode) {
        return @"F4";
    }
    return colorTemperatureMoreWarmKeyCode;
}

- (void)setColorTemperatureMoreWarmKey:(NSString *)colorTemperatureMoreWarmKeyCode {
    [NSUserDefaults.standardUserDefaults setObject:colorTemperatureMoreWarmKeyCode forKey:@"colorTemperatureMoreWarmKey"];
}

//-------

+ (void)saveBrightness:(int) newBrightness forDisplayID:(CGDirectDisplayID) displayID  {
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
    APP_DELEGATE.statusBarIcon.length = APP_DELEGATE.showBrightness ? APP_DELEGATE.currentBrightness == 100
                                                                    ? STATUS_ICON_WIDTH_TEXT_100 : STATUS_ICON_WIDTH_TEXT : STATUS_ICON_WIDTH;
}

+ (BOOL)loadSavedBrightness:(uint*) savedBrightness forDisplayID:(CGDirectDisplayID) displayID {
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
    if (! CGDisplayIsBuiltin(currentDisplayId)) {
        
        uint currentBrightness = 50;
        uint maxBrightness = 100;
        
        // Get the current display brightness
        // Fist, try user defaults to avoid waiting for a timeout if the display is known not to support DDCRead;
        // If user defaults are not set, read the brightness value from the display
        
        BOOL isCurrentBrighnessReadFromDefaults = [AppDelegate loadSavedBrightness:&currentBrightness forDisplayID:currentDisplayId];
        if (! isCurrentBrighnessReadFromDefaults) {
            get_control(currentDisplayId, BRIGHTNESS, &currentBrightness, &maxBrightness);
        }
        
        int currentBrightnessInSubsteps = round((double)currentBrightness / (double)maxBrightness * (double)brightnessSubstepsCount);
        int newBrightnessInSubsteps = MIN(MAX(0, currentBrightnessInSubsteps + deltaInSubsteps), brightnessSubstepsCount);
        if (abs(deltaInSubsteps) != 1) {
            // newBrightnessInSubsteps must be a multiple of deltaInSubsteps
            newBrightnessInSubsteps = (newBrightnessInSubsteps / deltaInSubsteps) * deltaInSubsteps;
        }
        
        uint newBrightness = (uint) round((double)newBrightnessInSubsteps / (double)brightnessSubstepsCount * (double)maxBrightness);
        newBrightness = MIN(APP_DELEGATE.maxBrightness, newBrightness);
        
        if (newBrightness != currentBrightness) {
            if (set_control(currentDisplayId, BRIGHTNESS, newBrightness)) {
                NSLog(@"New brightness: %d", newBrightness);
                APP_DELEGATE.statusBarIcon.title = APP_DELEGATE.showBrightness ? [NSString stringWithFormat:@"%i%%",newBrightness] : @"";
                // Display the brighness level OSD
                showBrightnessLevelPaneOnDisplay(newBrightnessInSubsteps, currentDisplayId);
                APP_DELEGATE.brightnessView.sliderBrightness.integerValue = newBrightness;
                [self saveBrightness:newBrightness forDisplayID:currentDisplayId];
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
            APP_DELEGATE.statusBarIcon.title = APP_DELEGATE.showBrightness ? [NSString stringWithFormat:@"%i%%",newBrightness] : @"";
            [AppDelegate saveBrightness:newBrightness forDisplayID:currentDisplayId];
        }
    }
}


+(void)changeScreenColorTemperature:(float) colorTemperature {
    [APP_DELEGATE.blueLight setStrength:colorTemperature commit:YES];
    APP_DELEGATE.colorTemperatureView.sliderColorTemperature.floatValue = colorTemperature;
}

+(void)changeScreenColorTemperatureStep:(float) colorTemperatureStep {
    APP_DELEGATE.colorTemperatureView.sliderColorTemperature.floatValue += colorTemperatureStep;
    [APP_DELEGATE.blueLight setStrength: APP_DELEGATE.colorTemperatureView.sliderColorTemperature.floatValue
                                 commit: YES];
    NSLog(@"Color Temperature Strength: %f",APP_DELEGATE.colorTemperatureView.sliderColorTemperature.floatValue);
}
@end
