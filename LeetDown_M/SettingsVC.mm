//
//  SettingsVC.m
//  LeetDown
//
//  Created by rA9stuff on 27.08.2021.
//

#import "SettingsVC.h"

@implementation SettingsVC

- (IBAction)debuggingToggle:(id)sender {
    
    modifyPref(@"DebugEnabled", [NSString stringWithFormat:@"%ld", (long)_debugEnabledToggle.state]);

    if (_debugEnabledToggle.state) {

        modifyPref(@"DebugEnabled", @"1");
        NSTask *restart = [[NSTask alloc] init];
        NSString *LDPath = [[NSBundle mainBundle] resourcePath];
        LDPath = [[LDPath substringToIndex:[LDPath length] -9] stringByAppendingString:@"MacOS/LeetDown"];
        restart.launchPath = LDPath;
        restart.arguments = @[];
        [restart launch];
        exit(0);
    }
}

- (IBAction)md5Action:(id)sender {
    modifyPref(@"skipMD5", [NSString stringWithFormat:@"%ld", (long)_skipipswCheckToggle.state]);
}

- (IBAction)resetReqAct:(id)sender {
    modifyPref(@"resetreq", [NSString stringWithFormat:@"%ld", (long)_reestRequestToggle.state]);
}
- (IBAction)downgradeBBAct:(id)sender {
    modifyPref(@"downgradeBB", [NSString stringWithFormat:@"%ld", (long)_downgradeBBoutlet.state]);
}

- (IBAction)modifyExploitPref:(id)sender {
    NSPopUpButton *popUpButton = (NSPopUpButton *)sender;
    NSInteger selectedIndex = [popUpButton indexOfSelectedItem];
    modifyPref(@"exploit_index", [NSString stringWithFormat:@"%li", (long)selectedIndex]);
}

- (IBAction)autoUpdateAct:(id)sender {
    modifyPref(@"autoUpdate", [NSString stringWithFormat:@"%ld", (long)_autoUpdate.state]);
}


- (IBAction)closeVC:(id)sender {

    [self.view.window.contentViewController dismissViewController:self];

}

-(void)awakeFromNib {
    
    NSColor *color = [NSColor whiteColor];
    NSMutableAttributedString *debugTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[_debugEnabledToggle attributedTitle]];
    NSRange debugRange = NSMakeRange(0, [debugTitle length]);
    [debugTitle addAttribute:NSForegroundColorAttributeName value:color range:debugRange];
    [_debugEnabledToggle setAttributedTitle:debugTitle];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *resetreq       = getPref(@"resetreq");
    NSString *debugStr       = getPref(@"DebugEnabled");
    NSString *md5Str         = getPref(@"skipMD5");
    NSString *downgradeBBstr = getPref(@"downgradeBB");
    NSString *exploit_index  = getPref(@"exploit_index");
    NSString *autoUpdate  = getPref(@"autoUpdate");
    
    _debugEnabledToggle.state  = ([debugStr isEqualToString:@"1"])       ? YES : NO;
    _skipipswCheckToggle.state = ([md5Str isEqualToString:@"1"])         ? YES : NO;
    _reestRequestToggle.state  = ([resetreq isEqualToString:@"1"])       ? YES : NO;
    _downgradeBBoutlet.state   = ([downgradeBBstr isEqualToString:@"1"]) ? YES : NO;
    _autoUpdate.state   = ([autoUpdate isEqualToString:@"1"]) ? YES : NO;
    
    [[self exploitSelectionBox] selectItemAtIndex:[exploit_index integerValue]];
    [self setPreferredContentSize: self.view.frame.size];
}
@end
