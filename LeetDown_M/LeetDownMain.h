//
//  ViewController.h
//  LeetDown_M
//
//  Created by rA9stuff on 12.07.2021.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "DFUHelperViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <CommonCrypto/CommonDigest.h>
#include "libirecovery.h"
#include <stdlib.h>
#include "SSZipArchive/SSZipArchive.h"
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>

@interface ViewController : NSViewController
@property (assign) IBOutlet NSView *mainView;
@property (weak) IBOutlet NSTextField *header;
@property (weak) IBOutlet NSScrollView *statusbox;
@property (unsafe_unretained) IBOutlet NSTextView *statuslabel;
@property (assign) IBOutlet NSButton *selectIPSWoutlet;
@property (assign) IBOutlet NSTextField *versionLabel;
@property (assign) IBOutlet NSBox *mainbox;
@property (weak) IBOutlet NSButton *downgradeButtonOut;
@property (weak) IBOutlet NSProgressIndicator *uselessIndicator;
@property (assign) IBOutlet NSButton *dfuhelpoutlet;
@property (assign) IBOutlet NSButton *prefGear;
@property (assign) IBOutlet NSTextField *percentage;
- (int) discoverDevices;
- (void)updateStatus:(NSString*)text color:(NSColor*)color1;
// Declare a property for your custom NSWindow instance
@property (strong, nonatomic) NSAlert *alert;
@end

@protocol USBDeviceDetectedDelegate <NSObject>

- (void)deviceDetected;

@end


