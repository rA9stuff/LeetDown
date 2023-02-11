//
//  USBUtils.c
//  LeetDown
//
//  Created by Baris U. Cukur on 10.02.2023.
//

#include "USBUtils.h"
#include <IOKit/usb/IOUSBLib.h>
#include "LDD.h"
#include "LeetDownMain.h"

@implementation USBUtils : NSObject

- (NSString*) getNameOfUSBDevice: (io_object_t) usbDevice {
    kern_return_t kernResult;
    CFMutableDictionaryRef properties = NULL;
    kernResult = IORegistryEntryCreateCFProperties(usbDevice, &properties, kCFAllocatorDefault, kNilOptions);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"Unable to access USB device properties");
        return @"err";
    }
    CFTypeRef nameRef = CFDictionaryGetValue(properties, CFSTR(kUSBProductString));
    if (!nameRef) {
        NSLog(@"Name not found");
        return @"err";
    }
    CFStringRef nameStrRef = (CFStringRef)nameRef;
    char nameCStr[1024];
    if (!CFStringGetCString(nameStrRef, nameCStr, 1024, kCFStringEncodingUTF8)) {
        NSLog(@"Unable to get C string representation of name");
        return @"err";
    }

    NSString *name = [NSString stringWithCString:nameCStr encoding:NSUTF8StringEncoding];
    NSLog(@"Name: %@", name);
    CFRelease(properties);
    return name;
}

- (void) USBDeviceDetectedCallback:(void *)refcon iterator: (io_iterator_t) iterator {
    io_object_t usbDevice;
    while ((usbDevice = IOIteratorNext(iterator))) {
        NSLog(@"USB device detected");
        NSString* name = [self getNameOfUSBDevice:usbDevice];
        if ([name isEqualToString:@"USB3.1 Hub"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"A USB Hub is connected"];
                [alert setInformativeText:@"Please note that USB Hubs can cause problems with DFU device communications. It is recommended to use a USB-C to USB-A adapter instead."];
                [alert runModal];
            });
        }
        else if ([name isEqualToString:@"Apple Mobile Device (DFU Mode)"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.vc discoverDevices];
                //[[NSNotificationCenter defaultCenter] postNotificationName:@"ViewControllerReloadData" object:nil];
            });
        }
        else if ([name isEqualToString:@"Apple Mobile Device (Recovery Mode)"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.vc updateStatus:@"Device is connected in recovery mode, place it in DFU mode to proceed" color:[NSColor redColor]];
            });
        }
        IOObjectRelease(usbDevice);
    }
}

static void DeviceAdded(void *refCon, io_iterator_t iterator)
{
    USBUtils *obj = (USBUtils *)refCon;
    [obj USBDeviceDetectedCallback:NULL iterator:iterator];
}

- (void) registerForUSBDeviceNotifications {
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
        NSLog(@"Unable to create matching dictionary for USB device detection");
        return;
    }
    io_iterator_t iterator;
    IONotificationPortRef notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(notificationPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    kern_return_t kernResult = IOServiceAddMatchingNotification(notificationPort, kIOPublishNotification,
                                                                matchingDict, DeviceAdded, (__bridge void*)self, &iterator);

    if (kernResult != kIOReturnSuccess) {
        NSLog(@"Unable to register for USB device detection notifications");
        return;
    }
    [self USBDeviceDetectedCallback:NULL iterator: iterator];
}

- (void) startMonitoringUSBDevices:(ViewController *)viewController {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.vc = viewController;
        [self registerForUSBDeviceNotifications];
        [[NSRunLoop currentRunLoop] run];
    });
}

@end
