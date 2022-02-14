//
//  SettingsVC.m
//  LeetDown
//
//  Created by rA9stuff on 27.08.2021.
//

#import "SettingsVC.h"

@implementation SettingsVC

plistModifier plistObject;

- (IBAction)debuggingToggle:(id)sender {
    
    plistObject.modifyPref(@"DebugEnabled", [NSString stringWithFormat:@"%ld", (long)_debugToggle.state]);

    if (_debugToggle.state) {

        plistObject.modifyPref(@"DebugEnabled", @"1");
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

    plistObject.modifyPref(@"skipMD5", [NSString stringWithFormat:@"%ld", (long)_md5Toggle.state]);
}

- (IBAction)resetReqAct:(id)sender {
    plistObject.modifyPref(@"resetreq", [NSString stringWithFormat:@"%ld", (long)_resetreq.state]);
}


- (IBAction)closeVC:(id)sender {
    
    [self.view.window.contentViewController dismissViewController:self];

}

-(void)awakeFromNib {
    
    NSColor *color = [NSColor whiteColor];
    NSMutableAttributedString *debugTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[_debugToggle attributedTitle]];
    NSRange debugRange = NSMakeRange(0, [debugTitle length]);
    [debugTitle addAttribute:NSForegroundColorAttributeName value:color range:debugRange];
    [_debugToggle setAttributedTitle:debugTitle];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *resetreq = plistObject.getPref(@"resetreq");
    NSString *debugStr = plistObject.getPref(@"DebugEnabled");
    NSString *md5Str = plistObject.getPref(@"skipMD5");
    _debugToggle.state = debugStr.longLongValue;
    _md5Toggle.state = md5Str.longLongValue;
    _resetreq.state = resetreq.longLongValue;

}
@end
