//
//  ViewController.h
//  LeetDown_M
//
//  Created by rA9stuff on 12.07.2021.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>


@interface ViewController : NSViewController

@property (weak) IBOutlet NSTextField *header;
@property (weak) IBOutlet NSScrollView *statusbox;
@property (unsafe_unretained) IBOutlet NSTextView *statuslabel;
@property (assign) IBOutlet NSButton *selectIPSWoutlet;
@property (assign) IBOutlet NSTextField *versionLabel;
@property (assign) IBOutlet NSBox *mainbox;
@property (weak) IBOutlet NSTextField *ramiel;
@property (weak) IBOutlet NSButton *downgradeButtonOut;
@property (weak) IBOutlet NSProgressIndicator *uselessIndicator;
@property (assign) IBOutlet NSButton *dfuhelpoutlet;
@property (assign) IBOutlet NSButton *prefGear;
@property (assign) IBOutlet NSTextField *percentage;

@end


