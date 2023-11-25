//
//  SettingsVC.h
//  LeetDown
//
//  Created by rA9stuff on 27.08.2021.
//

#import <Cocoa/Cocoa.h>
#import "LeetDownMain.h"
#import "libirecovery.h"
#include "PlistUtils.h"

void modifyPreference(NSNumber *val, NSString *preference);
@interface SettingsVC : NSViewController
@property (assign) IBOutlet NSButton *reestRequestToggle;
@property (nonatomic) BOOL booleanDraw;
@property (assign) IBOutlet NSButton *debugEnabledToggle;
@property (nonatomic, assign) BOOL locationUseBool;
@property (assign) IBOutlet NSButton *downgradeBBoutlet;
@property (assign) IBOutlet NSButton *skipipswCheckToggle;
@property (assign) IBOutlet NSPopUpButtonCell *exploitSelectionBox;
@property (assign) IBOutlet NSButton *autoUpdate;

@end
