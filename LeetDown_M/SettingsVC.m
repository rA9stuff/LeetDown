//
//  SettingsVC.m
//  LeetDown
//
//  Created by rA9stuff on 27.08.2021.
//

#import "SettingsVC.h"
#import "LeetDownMain.h"
#import "libirecovery.h"

bool checkDebug(void) {
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    NSString *stringValue=dict[@"DebugEnabled"];
    return stringValue.intValue;
}

void ModifyDebug(id _Nullable val) {
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    [dict setValue:val forKey:@"DebugEnabled"];
    [dict writeToFile:preferencePlist atomically:YES];
}


@implementation SettingsVC


- (IBAction)debuggingToggle:(id)sender {
    if (_debugToggle.state == false) {
        ModifyDebug([NSNumber numberWithInt:0]);
    }
    else {
        ModifyDebug([NSNumber numberWithInt:1]);
        NSTask *restart = [[NSTask alloc] init];
        NSString *LDPath = [[NSBundle mainBundle] resourcePath];
        LDPath = [[LDPath substringToIndex:[LDPath length] -9] stringByAppendingString:@"MacOS/LeetDown"];
        restart.launchPath = LDPath;
        restart.arguments = @[];
        [restart launch];
        exit(0);
    }
}

- (IBAction)closeVC:(id)sender {
    
    [self.view.window.contentViewController dismissViewController:self];

}

-(void)awakeFromNib
{
    NSColor *color = [NSColor whiteColor];
    NSMutableAttributedString *debugTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[_debugToggle attributedTitle]];
    NSMutableAttributedString *frTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[_futureToggle attributedTitle]];
    NSRange debugRange = NSMakeRange(0, [debugTitle length]);
    NSRange frRange = NSMakeRange(0, [frTitle length]);
    [debugTitle addAttribute:NSForegroundColorAttributeName value:color range:debugRange];
    [frTitle addAttribute:NSForegroundColorAttributeName value:color range:frRange];
    [_debugToggle setAttributedTitle:debugTitle];
    [_futureToggle setAttributedTitle:frTitle];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _debugToggle.state = checkDebug();
}
@end
