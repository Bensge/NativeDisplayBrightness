//
//  DDCM1.h
//  NativeDisplayBrightness
//
//  Created by Cédric Vuillet on 05/08/2021.
//  Copyright © 2021 Benno Krauss. All rights reserved.
//

#ifndef DDCM1_h
#define DDCM1_h

/*struct DDCWriteCommand
{
    UInt8 control_id;
    UInt8 new_value;
};*/

bool DDCM1Write(uint level);

#endif /* DDCM1_h */
