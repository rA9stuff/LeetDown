//
//  SettingsVC.h
//  LeetDown
//
//  Created by rA9stuff on 27.08.2021.
//

#import <Cocoa/Cocoa.h>
#import "LeetDownMain.h"
#import "libirecovery.h"
#include "plistModifier.h"

void modifyPreference(NSNumber *val, NSString *preference);
@interface SettingsVC : NSViewController
@property (assign) IBOutlet NSButton *resetreq;
@property (nonatomic) BOOL booleanDraw;
@property (assign) IBOutlet NSButton *debugToggle;
@property (assign) IBOutlet NSButton *md5Toggle;
@property (nonatomic, assign) BOOL locationUseBool;
@end
