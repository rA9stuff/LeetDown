//
//  SettingsVC.h
//  LeetDown
//
//  Created by rA9stuff on 27.08.2021.
//

#import <Cocoa/Cocoa.h>


@interface SettingsVC : NSViewController
@property (nonatomic) BOOL booleanDraw;
@property (assign) IBOutlet NSButton *debugToggle;
@property (assign) IBOutlet NSButton *futureToggle;
@property (nonatomic, assign) BOOL locationUseBool;
@end
