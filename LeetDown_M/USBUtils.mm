//
//  USBUtils.mm
//  LeetDown
//
//  Created by rA9stuff on 10.02.2023.
//

#include "USBUtils.h"
#include <IOKit/usb/IOUSBLib.h>
#include "LDD.h"
#include "LeetDownMain.h"

extern bool restoreStarted;
extern bool discoverStateEnded;
bool trapDevice = false;

@implementation USBUtils : NSObject

- (NSString*) getNameOfUSBDevice: (io_object_t) usbDevice {
    kern_return_t kernResult;
    CFMutableDictionaryRef properties = NULL;
    kernResult = IORegistryEntryCreateCFProperties(usbDevice, &properties, kCFAllocatorDefault, kNilOptions);
    if (kernResult != KERN_SUCCESS) {
        printf("Unable to access USB device properties\n");
        return @"err";
    }
    CFTypeRef nameRef = CFDictionaryGetValue(properties, CFSTR(kUSBProductString));
    if (!nameRef) {
        printf("Name not found\n");
        return @"err";
    }
    CFStringRef nameStrRef = (CFStringRef)nameRef;
    char nameCStr[1024];
    if (!CFStringGetCString(nameStrRef, nameCStr, 1024, kCFStringEncodingUTF8)) {
        printf("Unable to get C string representation of name\n");
        return @"err";
    }

    NSString *name = [NSString stringWithCString:nameCStr encoding:NSUTF8StringEncoding];
    printf("Name: %s\n", name.UTF8String);
    CFRelease(properties);
    return name;
}

- (void) USBDeviceDetectedCallback:(void *)refcon iterator: (io_iterator_t) iterator {
    io_object_t usbDevice;
    while ((usbDevice = IOIteratorNext(iterator))) {
        
        printf("New USB device detected\n");
        NSString* name = [self getNameOfUSBDevice:usbDevice];
        if ([name isEqualToString:@"USB2.1 Hub"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"A USB Hub is connected"];
                [alert setInformativeText:@"Please note that USB Hubs can cause problems with DFU device communications. It is recommended to use a USB-C to USB-A adapter instead."];
                [alert runModal];
            });
        }
        else if (([name isEqualToString:@"iPhone"] || [name isEqualToString:@"iPad"]) && !trapDevice) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.vc updateStatus:[NSString stringWithFormat:@"Found an %@, attempting to connect...", name] color:[NSColor whiteColor]];
            });
            [self.vc discoverNormalDevices];
            trapDevice = true;
            sleep(1);
        }
        else if (!discoverStateEnded && ([name isEqualToString:@"Apple Mobile Device (Recovery Mode)"] || [name isEqualToString:@"Apple Mobile Device (DFU Mode)"])) {
            [self stopMonitoringUSBDevices];
            [self.vc discoverRestoreDevices:0];
            [self.vc exploitDevice];
            dispatch_async(dispatch_get_main_queue(), ^{
                
                if (!restoreStarted) {
                    NSString* formattedName = [name substringFromIndex:21];
                    formattedName = [formattedName substringToIndex:[formattedName length] - 1];
                    [self.vc updateStatus:[NSString stringWithFormat:@"Device is connected in %@, place it in normal mode to proceed", formattedName] color:[NSColor redColor]];
                }
            });
        }
        IOObjectRelease(usbDevice);
    }
}

static void DeviceAdded(void *refCon, io_iterator_t iterator) {
    USBUtils *obj = (USBUtils *)refCon;
    [obj USBDeviceDetectedCallback:NULL iterator:iterator];
}

static void DeviceRemoved(void *refCon, io_iterator_t iterator) {
    USBUtils *obj = (USBUtils *)refCon;
    [obj USBDeviceRemovedCallback:NULL iterator:iterator];
}

- (void) USBDeviceRemovedCallback:(void *)refcon iterator: (io_iterator_t) iterator {
    
    io_object_t usbDevice;
    while ((usbDevice = IOIteratorNext(iterator))) {
        
        if ([self detectTrapRemoval])
            continue;
        
        NSString* name = [self getNameOfUSBDevice:usbDevice];
        printf("Lost USB device: %s\n", name.UTF8String);
        
        if ([name isEqualToString:@"Apple Mobile Device (DFU Mode)"] || [name isEqualToString:@"Apple Mobile Device (Recovery Mode)"] || [name isEqualToString:@"iPhone"] || [name isEqualToString:@"iPad"] || [name isEqualToString:@"iPod"]) {
            trapDevice = false;
        }
        IOObjectRelease(usbDevice);
    }
}

- (BOOL) detectTrapRemoval {
    @autoreleasepool {
        CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
        io_iterator_t iter;
        IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter);
        io_service_t usbDevice;
        while ((usbDevice = IOIteratorNext(iter))) {
            // Get device name
            NSString* devname = [self getNameOfUSBDevice:usbDevice];
            if ([devname isEqualToString:@"iPhone"] || [devname isEqualToString:@"iPad"] || [devname isEqualToString:@"iPod"]) {
                printf("%s Device switched state!\n", __func__);
                return true;
            }
            IOObjectRelease(usbDevice);
        }
        IOObjectRelease(iter);
    }
    return false;
}

io_iterator_t detectionIterator, removalIterator;

- (void) registerForUSBDeviceNotifications {
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
        printf("Unable to create matching dictionary for USB device detection\n");
        return;
    }

    IONotificationPortRef notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(notificationPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    kern_return_t kernResult = IOServiceAddMatchingNotification(notificationPort, kIOPublishNotification, matchingDict, DeviceAdded, (__bridge void*)self, &detectionIterator);

    if (kernResult != kIOReturnSuccess) {
        printf("Unable to register for USB device detection notifications\n");
        return;
    }
    [self USBDeviceDetectedCallback:NULL iterator: detectionIterator];
    
    CFMutableDictionaryRef removalMatchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!removalMatchingDict) {
        NSLog(@"Unable to create matching dictionary for USB device detection");
        return;
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    kernResult = IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification, removalMatchingDict, DeviceRemoved, (__bridge void*)self, &removalIterator);

    if (kernResult != kIOReturnSuccess) {
        NSLog(@"Unable to register for USB device detection notifications");
        return;
    }
    [self USBDeviceRemovedCallback:NULL iterator:removalIterator];
}

- (void) startMonitoringUSBDevices:(ViewController *)viewController {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.vc = viewController;
        [self registerForUSBDeviceNotifications];
        [[NSRunLoop currentRunLoop] run];
    });
}

- (void) stopMonitoringUSBDevices {
    IOObjectRelease(detectionIterator);
    IOObjectRelease(removalIterator);
}

@end
