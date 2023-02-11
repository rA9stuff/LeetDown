//
//  USBUtils.h
//  LeetDown
//
//  Created by Baris U. Cukur on 10.02.2023.
//

#ifndef USBUtils_h
#define USBUtils_h

#include <stdio.h>
#include <IOKit/usb/IOUSBLib.h>
#import <Foundation/Foundation.h>
#import "LeetDownMain.h"

@interface USBUtils : NSObject

- (void)startMonitoringUSBDevices:(ViewController *) vc;
- (NSString*) getNameOfUSBDevice:(io_object_t) usbDevice;
- (void) USBDeviceDetectedCallback:(void *)refcon iterator: (io_iterator_t) iterator;
- (void) registerForUSBDeviceNotifications;
@property (nonatomic, strong) ViewController* vc;

@end

//NSString* getNameOfUSBDevice(io_object_t usbDevice);
//void USBDeviceDetectedCallback(void *refcon, io_iterator_t iterator);
//void registerForUSBDeviceNotifications();
//void startMonitoringUSBDevices();


#endif /* USBUtils_h */
