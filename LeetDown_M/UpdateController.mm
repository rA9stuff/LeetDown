//
//  VersionChecker.m
//  LeetDown
//
//  Created by rA9stuff on 23.11.2023.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <AFNetworking/AFNetworking.h>
#import "UpdateController.h"
#import "PlistUtils.h"
#import "SSZipArchive/SSZipArchive.h"
#import <math.h>

@implementation UpdateController

+ (void)sendGETRequestWithURL:(NSString *)urlString completion:(void (^)(NSDictionary *, NSError *))completion {
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

        if (jsonError) {
            completion(nil, jsonError);
        } else {
            completion(jsonResponse, nil);
        }
    }];

    [dataTask resume];
}

- (void)getAssetInfoWithCompletion:(void (^)(NSDictionary *response, NSError *error))completion {
    
    if ([getPref(@"nightlyHash") isEqual: @""]) {
        [UpdateController sendGETRequestWithURL:@"https://api.github.com/repos/rA9stuff/LeetDown/releases/latest" completion:^(NSDictionary *response, NSError *error) {
            if (completion) {
                completion(response, error);
            }
        }];
    }
    else {
        [UpdateController sendGETRequestWithURL:@"https://api.github.com/repos/rA9stuff/LeetDown/actions/artifacts" completion:^(NSDictionary *response, NSError *error) {
            if (completion) {
                completion(response, error);
            }
        }];
    }
}

- (void) updateLD {
    
    [self getAssetInfoWithCompletion:^(NSDictionary *response, NSError *error) {
        if (error) {
            // Handle error
            NSLog(@"Error: %@", error.localizedDescription);
        }
        else {
            bool nightly = ![getPref(@"nightlyHash")  isEqual: @""] ? true : false;
            NSString* downloadURL = @"";
            NSString* assetName = @"";
            
            if (nightly) {
                downloadURL = @"https://nightly.link/rA9stuff/LeetDown/workflows/ci/master/LeetDown-Nightly.zip";
                assetName = @"LeetDown_Nightly.zip";
            }
            else {
                downloadURL = response[@"assets"][0][@"browser_download_url"];
                assetName = response[@"assets"][0][@"name"];
            }
            dispatch_async(dispatch_get_main_queue(),^{
                [[self statusStr] setStringValue:@"Downloading..."];
            });
            
            // use nsfilemanager to move the updater to the temp directory
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager createDirectoryAtPath:[NSTemporaryDirectory() stringByAppendingString:@"LD"] withIntermediateDirectories:NO attributes:nil error:nil];
            
            printf("Downloading %s from %s\n", assetName.UTF8String, downloadURL.UTF8String);
            
            NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
            AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
            NSURL *formattedURL = [NSURL URLWithString:downloadURL];
            NSURLRequest *request = [NSURLRequest requestWithURL:formattedURL];
            NSURL *tempURL = [NSURL URLWithString: NSTemporaryDirectory()];
            NSURL *fullURL = [[tempURL URLByAppendingPathComponent:@"LD"] URLByAppendingPathComponent:assetName];
            
            // extremely hacky but will do for now...
            NSString *fileURL = [@"file://" stringByAppendingString:[NSString stringWithFormat:@"%@", fullURL]];

            [manager setDownloadTaskDidWriteDataBlock:^(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
                
                CGFloat written = totalBytesWritten;
                CGFloat total = totalBytesExpectedToWrite;
                written = written/(1024*1024);
                total = total/(1024*1024);
                NSString *writtenSTR = [NSString stringWithFormat:@"%f", written];
                NSString *totalSTR = [NSString stringWithFormat:@"%f", total];
                writtenSTR = [writtenSTR substringToIndex:[writtenSTR length] -4];
                totalSTR = [totalSTR substringToIndex:[totalSTR length] -4];
                CGFloat percentageCompleted = written/total;
                if (nightly) {
                    percentageCompleted /= -10000000;
                }
                NSLog(@"%f\n", percentageCompleted);
                NSString *percentageSTR = [NSString stringWithFormat:@"%f", percentageCompleted];
                percentageSTR = [percentageSTR substringToIndex:[percentageSTR length] -4];
                if ([percentageSTR doubleValue] >= 0.10) {
                    percentageSTR = [percentageSTR substringFromIndex:2];
                }
                else {
                    percentageSTR = [percentageSTR substringFromIndex:3];
                }
                percentageSTR = [percentageSTR stringByAppendingString:@"%"];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_updateProgress setDoubleValue:percentageCompleted];
                });
            }];
            
            NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
                return [NSURL URLWithString: fileURL];
            }
            completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
                
                // move LDUpdater to NSTemporaryDirectory
                NSString *tempPath = NSTemporaryDirectory();
                NSString *updaterPath = [[NSBundle mainBundle] resourcePath];
                updaterPath = [[updaterPath substringToIndex:[updaterPath length] -9] stringByAppendingString:@"MacOS/LDUpdater"];
                
                [fileManager copyItemAtPath:updaterPath toPath:[tempPath stringByAppendingString:@"LD/LDUpdater"] error:&error];
                if (error) {
                    printf("Error moving updater to temp directory: %s\n", error.localizedDescription.UTF8String);
                }
                
                if (nightly) {
                    // unzip the downloaded file with ssziparchive
                    NSString *zipPath = [tempPath stringByAppendingString:@"LD/LeetDown_Nightly.zip"];
                    NSString *destinationPath = [tempPath stringByAppendingString:@"LD/"];
                    [SSZipArchive unzipFileAtPath:zipPath toDestination:destinationPath];
                }
                
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_updateProgress setDoubleValue:1.0];
                        [[self statusStr] setStringValue:@"Installing..."];
                    });
                    // find the file with .dmg extension
                    NSString *dmgFilePath = @"";
                    NSArray *dirContents = [fileManager contentsOfDirectoryAtPath:[tempPath stringByAppendingString:@"LD"] error:nil];
                    for (NSString *file in dirContents) {
                        if ([file containsString:@".dmg"]) {
                            dmgFilePath = [tempPath stringByAppendingString:[NSString stringWithFormat:@"LD/%@", file]];
                        }
                    }
                    sleep(1);
                    NSTask *LDUpdater = [[NSTask alloc] init];
                    [LDUpdater setLaunchPath:[NSTemporaryDirectory() stringByAppendingString:@"LD/LDUpdater"]];
                    [LDUpdater setArguments:@[[NSString stringWithFormat:@"%@", (nightly ? dmgFilePath : fullURL)]]];
                    [LDUpdater launch];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.view.window.contentViewController dismissViewController:self];
                        [[NSApplication sharedApplication] terminate:nil];
                    });
                });
            }];
            [downloadTask resume];
        }
    }];
}

- (void) viewDidLoad {

    // make the window non resizable
    [self setPreferredContentSize: self.view.frame.size];
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *iconPath = [mainBundle pathForResource:@"AppIcon" ofType:@"icns"];
    NSImage *appIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    NSSize imageSize = NSMakeSize(80.0, 80.0);
    [appIcon setSize:imageSize];
    
    // check if LD directory exists in temp directory
    NSFileManager *filemanager = [[NSFileManager defaultManager] init];
    if ([filemanager fileExistsAtPath:[NSTemporaryDirectory() stringByAppendingString:@"LD"]]) {
        [filemanager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:@"LD"] error:nil];
    }
    
    [[self statusStr] setStringValue:@"Checking for updates..."];
    [[self LDIcon] setImage:appIcon];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self updateLD];
    });
}


@end
