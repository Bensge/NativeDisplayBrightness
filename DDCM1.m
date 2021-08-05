//
//  DDCM1.m
//  NativeDisplayBrightness
//
//  Created by Cédric Vuillet on 05/08/2021.
//  Copyright © 2021 Benno Krauss. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "DDCM1.h"

@import Darwin;
@import Foundation;
@import IOKit;

// clang -fmodules -o i2cwrite i2cwrite.m && ./i2cwrite

typedef CFTypeRef IOAVServiceRef;
extern IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);

extern IOReturn IOAVServiceCopyEDID(IOAVServiceRef service, CFDataRef* x2);
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void* outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void* inputBuffer, uint32_t inputBufferSize);

#define BRIGHTNESS 0x10
#define CONTRAST 0x12
#define AUDIO_SPEAKER_VOLUME 0x62
#define AUDIO_MUTE 0x8D
#define INPUT_SOURCE 0x60
#define DPMS 0xD6

struct DDCWriteCommand {
    UInt8 control_id;
    UInt8 new_value;
};

bool DDCM1Write(uint level) {
    io_iterator_t iter;
    io_service_t service = 0;
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMasterPortDefault);
    kern_return_t kerr = IORegistryEntryCreateIterator(root, "IOService", kIORegistryIterateRecursively, &iter);
    if (kerr != KERN_SUCCESS) {
        IOObjectRelease(iter);
        NSLog(@"Error on IORegistryEntryCreateIterator: %d", kerr);
        return 1;
    }

    CFStringRef edidUUIDKey = CFStringCreateWithCString(kCFAllocatorDefault, "EDID UUID", kCFStringEncodingASCII);
    CFStringRef locationKey = CFStringCreateWithCString(kCFAllocatorDefault, "Location", kCFStringEncodingASCII);
    CFStringRef displayAttributesKey = CFStringCreateWithCString(kCFAllocatorDefault, "DisplayAttributes", kCFStringEncodingASCII);
    CFStringRef externalAVServiceLocation = CFStringCreateWithCString(kCFAllocatorDefault, "External", kCFStringEncodingASCII);
    
    int found = 0;
    while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        io_name_t name;
        IORegistryEntryGetName(service, name);
        if (strcmp(name, "AppleCLCD2") == 0) {
            CFStringRef edidUUID = IORegistryEntrySearchCFProperty(service, kIOServicePlane, edidUUIDKey, kCFAllocatorDefault, kIORegistryIterateRecursively);
            CFDictionaryRef displayAttrs = IORegistryEntrySearchCFProperty(service, kIOServicePlane, displayAttributesKey, kCFAllocatorDefault, kIORegistryIterateRecursively);
            if (displayAttrs) {
                NSDictionary* displayAttrsNS = (__bridge NSDictionary*)displayAttrs;
                NSDictionary* productAttrs = [displayAttrsNS objectForKey:@"ProductAttributes"];
                if (productAttrs) {
                    NSString* monitorName = [productAttrs objectForKey:@"ProductName"];
                    NSLog(@"Testing monitor %@ [UUID: %@]", monitorName, edidUUID);
                    NSLog(@"Attributes: %@", productAttrs);
                    found = 1;
                }
            }
        }
        if (strcmp(name, "DCPAVServiceProxy") == 0 && found == 1) {
            IOAVServiceRef avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service);
            CFStringRef location = IORegistryEntrySearchCFProperty(service, kIOServicePlane, locationKey, kCFAllocatorDefault, kIORegistryIterateRecursively);
            if (location == NULL) {
                NSLog(@"No location for service %d: %s\n\n\n", service, name);
                continue;
            }

            if (!avService) {
                NSLog(@"No AVService for service %d: %s\n\n\n", service, name);
                continue;
            }

            if (CFStringCompare(externalAVServiceLocation, location, 0) == 0) {
                NSLog(@"Found External AVService for %d: %d", service, avService);
            } else {
                NSLog(@"Found Embedded AVService for %d: %d\n\n\n", service, avService);
                continue;
            }

            struct DDCWriteCommand command;
            command.control_id = BRIGHTNESS;

            UInt8 data[256];
            memset(data, 0, sizeof(data));
            data[0] = 0x84;
            data[1] = 0x03;
            data[2] = command.control_id;
            
            command.new_value = level;
            NSLog(@"Setting BRIGHTNESS to %d", command.new_value);

            data[3] = (command.new_value) >> 8;
            data[4] = command.new_value & 255;
            data[5] = 0x6E ^ 0x51 ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4];

            for (int i = 0; i < 3; ++i) {
                IOReturn err = IOAVServiceWriteI2C(avService, 0x37, 0x51, data, 6);
                if (err) {
                    NSLog(@"i2c error: %s", mach_error_string(err));
                }
                usleep(32000);
            }
        }
    }
    CFRelease(locationKey);
    CFRelease(edidUUIDKey);
    CFRelease(displayAttributesKey);
    CFRelease(externalAVServiceLocation);
    
    return YES;
}
