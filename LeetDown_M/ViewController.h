//
//  ViewController.h
//  LeetDown_M
//
//  Created by Barış Ulaş Çukur on 12.07.2021.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>


@interface ViewController : NSViewController


@property (weak) IBOutlet NSTextField *header;

@property (weak) IBOutlet NSScrollView *statusbox;
@property (unsafe_unretained) IBOutlet NSTextView *statuslabel;
@property (weak) IBOutlet NSButton *selectIPSWoutlet;
@property (weak) IBOutlet NSTextField *ramiel;
@property (weak) IBOutlet NSButton *downgradeButtonOut;
@property (weak) IBOutlet NSProgressIndicator *uselessIndicator;


@end


