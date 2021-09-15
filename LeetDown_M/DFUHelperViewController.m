//
//  DFUHelperViewController.m
//  LeetDown
//
//  Created by rA9stuff on 1.08.2021.
//

#import "DFUHelperViewController.h"
#import "LeetDownMain.h"

@implementation DFUHelperViewController

- (IBAction)cancel:(id)sender {
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self.view.window.contentViewController dismissViewController:self];
    });
    
}

- (IBAction)startbutton:(id)sender {
    
    
    _startbutton.enabled = false;
    _startbutton.alphaValue = 0;
    _getreadyCounter.alphaValue = 1;
    _getreadytext.alphaValue = 1;
    _iphonepic.alphaValue = 0.5;
    _firsttext.alphaValue = 0.3;
    _secondtext.alphaValue = 0.3;
    _firstcounter.alphaValue = 0.3;
    _secondcounter.alphaValue = 0.3;
    _homebuttonimage.alphaValue = 0;
    _lockbuttonimage.alphaValue = 0;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        for (int i = 5; i > 0; i--) {
            dispatch_async(dispatch_get_main_queue(), ^(){
                _getreadyCounter.stringValue = [NSString stringWithFormat:@"%d", i];
            });
            sleep(1);
        }
        dispatch_async(dispatch_get_main_queue(), ^(){
            _getreadyCounter.stringValue = @"0";
            _getreadyCounter.alphaValue = 0.3;
            _getreadytext.alphaValue = 0.3;
        });
        
        dispatch_async(dispatch_get_main_queue(), ^(){
            _lockbuttonimage.alphaValue = 1;
            _homebuttonimage.alphaValue = 1;
            _firsttext.alphaValue = 1;
            _firstcounter.alphaValue = 1;
        });
        
        for (int i = 10; i > 0; i--) {
            dispatch_async(dispatch_get_main_queue(), ^(){
                _firstcounter.stringValue = [[NSString stringWithFormat:@"%d", i] stringByAppendingString:@" seconds"];
            });
            sleep(1);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(){
            _firstcounter.stringValue = @"0 seconds";
        });
        dispatch_async(dispatch_get_main_queue(), ^(){
            _firsttext.alphaValue = 0.3;
            _firstcounter.alphaValue = 0.3;
            _secondtext.alphaValue = 1;
            _secondcounter.alphaValue = 1;
            _lockbuttonimage.alphaValue = 0;
        });
        
        for (int i = 10; i > 0; i--) {
            dispatch_async(dispatch_get_main_queue(), ^(){
                _secondcounter.stringValue = [[NSString stringWithFormat:@"%d", i] stringByAppendingString:@" seconds"];
            });
            sleep(1);
        }
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self.view.window.contentViewController dismissViewController:self];
        });
        complete = true;
    });
    
    if (complete) {
        
    }
}

-(void)awakeFromNib
{
    NSColor *color = [NSColor greenColor];
    NSMutableAttributedString *colorTitle = [[NSMutableAttributedString alloc] initWithAttributedString:[_startbutton attributedTitle]];
    NSRange titleRange = NSMakeRange(0, [colorTitle length]);
    [colorTitle addAttribute:NSForegroundColorAttributeName value:color range:titleRange];
    [_startbutton setAttributedTitle:colorTitle];
}

bool complete = false;
- (void) viewDidLoad {
    
    [super viewDidLoad];
    
    _getreadyCounter.alphaValue = 0.1;
    _getreadytext.alphaValue = 0.1;
    _iphonepic.alphaValue = 0.1;
    _firsttext.alphaValue = 0.1;
    _secondtext.alphaValue = 0.1;
    _firstcounter.alphaValue = 0.1;
    _secondcounter.alphaValue = 0.1;
    _homebuttonimage.alphaValue = 0;
    _lockbuttonimage.alphaValue = 0;
    _homebuttonimage.image = [NSImage imageNamed:@"homebuttonimage"];
    
}

@end
