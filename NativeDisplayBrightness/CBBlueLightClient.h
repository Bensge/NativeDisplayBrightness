//
//  CBBlueLightClient.h
//  NightShifter
//
//  Created by Eric Lanini on 6/11/17.
//  Copyright © 2017 Eric Lanini. All rights reserved.
//

#ifndef CBBlueLightClient_h
#define CBBlueLightClient_h

typedef struct {
    int hour;
    int minute;
} Time;

typedef struct {
    Time fromTime;
    Time toTime;
} Schedule;

typedef struct {
    char active;
    char enabled;
    char sunSchedulePermitted;
    int mode;
    Schedule schedule;
    unsigned long long disableFlags;
} StatusData;

@interface CBBlueLightClient : NSObject
- (BOOL)setStrength:(float)arg1 commit: (BOOL)arg2;
- (BOOL)getStrength:(float *)arg1;
- (BOOL)setEnabled:(BOOL)arg1;
+ (BOOL)supportsBlueLightReduction;
- (BOOL)getBlueLightStatus:(StatusData *)arg1;
@end

#endif /* CBBlueLightClient_h */
