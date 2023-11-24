//
//  main.m
//  LDUpdater
//
//  Created by rA9stuff on 24.11.2023.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // grab launch arguments
        NSArray *args = [[NSProcessInfo processInfo] arguments];

        if ([args count] != 2) {
            printf("Usage: LDUpdater <url of LD Bundle>\n");
            return -1;
        }
        NSString *fullURL = [args objectAtIndex:1];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
        NSString *dateString = [formatter stringFromDate:[NSDate date]];
        NSString *volumePath = [@"/Volumes/" stringByAppendingString:dateString];
        
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/hdiutil"];
        [task setArguments:@[@"attach", [NSString stringWithFormat:@"%@", fullURL], @"-nobrowse", @"-mountpoint", volumePath]];
        [task launch];
        [task waitUntilExit];
        
        if ([task terminationStatus] != 0) {
            printf("Error: %d\n", [task terminationStatus]);
            return -1;
        }
        printf("Copying app to /Applications\n");
        // use nstask to tell cp to copy the app to /Applications
        NSString *appPath = [volumePath stringByAppendingString:@"/LeetDown.app"];
        task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/cp"];
        [task setArguments:@[@"-R", appPath, @"/Applications/"]];
        [task launch];
        [task waitUntilExit];
        
        if ([task terminationStatus] != 0) {
            printf("Error copying app to /Applications\n");
            return -1;
        }
        printf("Unmounting dmg\n");
        // use nstask to tell hdutil to unmount the dmg
        task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/hdiutil"];
        [task setArguments:@[@"detach", volumePath]];
        [task launch];
        [task waitUntilExit];
        
        if ([task terminationStatus] != 0) {
            printf("Error unmounting dmg\n");
            return -1;
        }
        
        printf("Done, relaunching...");
        
        NSTask *launch = [[NSTask alloc] init];
        NSString *LDPath = [[NSBundle mainBundle] resourcePath];
        LDPath = [[LDPath substringToIndex:[LDPath length] -9] stringByAppendingString:@"MacOS/LeetDown"];
        printf("launching %s\n", LDPath.UTF8String);
        launch.launchPath = @"/Applications/LeetDown.app/Contents/MacOS/LeetDown";
        launch.arguments = @[];
        [launch launch]; // fr
    }
    return 0;
}
