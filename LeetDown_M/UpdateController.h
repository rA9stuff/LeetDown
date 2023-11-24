//
//  MyNetwork.h
//  LeetDown
//
//  Created by rA9stuff on 23.11.2023.
//

#import <Foundation/Foundation.h>

@interface UpdateController: NSViewController

@property (assign) IBOutlet NSProgressIndicator *updateProgress;
@property (assign) IBOutlet NSImageView *LDIcon;
@property (assign) IBOutlet NSTextField *statusStr;

+ (void)sendGETRequestWithURL:(NSString *)urlString completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)updateLD;

@end

