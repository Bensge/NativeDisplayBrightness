//
//  OSD.h
//  NativeDisplayBrightness
//
//  Created by Benno Krauss on 23.10.16.
//  Copyright © 2016 Benno Krauss. All rights reserved.
//

#ifndef OSD_h
#define OSD_h

typedef enum {
    OSDGraphicBacklight                              = 1,//0xfffffff7,
    OSDGraphicEject                                  = 6,
    OSDGraphicNoWiFi                                 = 9,
    //You can reverse these yourself if you need them, it's easy trial-and-error
    /*
     BSGraphicKeyboardBacklightMeter                 = //0xfffffff1,
     BSGraphicKeyboardBacklightDisabledMeter         = //0xfffffff0,
     BSGraphicKeyboardBacklightNotConnected          = //0xffffffef,
     BSGraphicKeyboardBacklightDisabledNotConnected  = //0xffffffee,
     BSGraphicMacProOpen                             = //0xffffffe9,
     BSGraphicSpeakerMuted                           = //0xffffffe8,
     BSGraphicSpeaker                                = //0xffffffe7,
     BSGraphicSpeakerDisabled                        = //0xffffffe7,
     BSGraphicRemoteBattery                          = //0xffffffe6,
     BSGraphicHotspot                                = //0xffffffe5,
     BSGraphicSleep                                  = //0xffffffe3,
     BSGraphicSpeaker                                = 3//0xffffffe2,
     BSGraphicNewRemoteBattery                       = //0xffffffcb,
     */
} OSDGraphic;

typedef enum {
    OSDPriorityDefault = 0x1f4
} OSDPriority;

@interface OSDManager : NSObject
+ (instancetype)sharedManager;
- (void)showImage:(OSDGraphic)image onDisplayID:(CGDirectDisplayID)display priority:(OSDPriority)priority msecUntilFade:(int)timeout;
- (void)showImage:(OSDGraphic)image onDisplayID:(CGDirectDisplayID)display priority:(OSDPriority)priority msecUntilFade:(int)timeout withText:(NSString *)text;
- (void)showImage:(OSDGraphic)image onDisplayID:(CGDirectDisplayID)display priority:(OSDPriority)priority msecUntilFade:(int)timeout filledChiclets:(int)filled totalChiclets:(int)total locked:(BOOL)locked;
@end


#endif /* OSD_h */
