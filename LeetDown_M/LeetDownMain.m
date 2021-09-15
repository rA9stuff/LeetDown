#import "LeetDownMain.h"
#include "libirecovery.h"
#include <stdlib.h>
#include "SSZipArchive/SSZipArchive.h"
#define USB_TIMEOUT 10000
#import "DFUHelperViewController.h"
#import <AFNetworking/AFNetworking.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>

uint64_t ecid = 0;
bool connected = false;


NSString* NSCPID(const unsigned int *buf) {
    NSMutableString *ms=[[NSMutableString alloc] init];
    for (int i = 0; i < 1; i++) {
        [ms appendFormat:@"%04x", buf[i]];
    }
    return ms;
}

NSString* NSNonce(unsigned char *buf, size_t len) {
    NSMutableString *nonce=[[NSMutableString alloc] init];
    for (int i = 0; i < len; i++) {
        [nonce appendFormat:@"%02x", buf[i]];
    }
    return nonce;
}

id _Nullable getDestinationFromPlist(void) {
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    NSString *dfw=dict[@"DestinationFW"];
    return dfw;
}

int saveOTABlob(irecv_client_t client, irecv_device_t device) {
    
    client = NULL;
    device = NULL;
    
    
    for (int i = 0; i < 5; i++) {
        irecv_error_t erro = irecv_open_with_ecid(&client, ecid);
        printf("saveOTABlob is attempting to connect... \n");
        
        if (i == 4) {
            printf("saveOTABlob() failed to connect! \n");
            return -1;
        }
        
        if (erro == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(erro));
        }
        else if (erro != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        else {
            printf("saveOTABlob connected successfully! \n");
            break;
        }
    }
    
    const struct irecv_device_info *devinfo = irecv_get_device_info(client);
    irecv_devices_get_device_by_client(client, &device);
    
    NSMutableString *blobname = NULL;
    
    NSString *devecid = [NSString stringWithFormat:@"%llu", devinfo ->ecid];
    NSString *devmodel = [NSString stringWithFormat:@"%s", device ->product_type];
    NSString *apnonce = [NSString stringWithFormat:@"%@", NSNonce(devinfo -> ap_nonce, devinfo -> ap_nonce_size)];
    NSString *board = [NSString stringWithFormat:@"%s", device ->hardware_model];
    if (strcmp(device -> product_type, "iPhone6,1") == 0 || strcmp(device -> product_type, "iPhone6,2") == 0 || strcmp(device -> product_type, "iPad4,1") == 0 || strcmp(device -> product_type, "iPad4,2") == 0 || strcmp(device -> product_type, "iPad4,3") == 0 || strcmp(device -> product_type, "iPad4,4") == 0 || strcmp(device -> product_type, "iPad4,5") == 0) {
        
    blobname = [[[[[[[[devecid stringByAppendingString:@"_"] stringByAppendingString: devmodel] stringByAppendingString:@"_"] stringByAppendingString: board] stringByAppendingString:@"_10.3.3-14G60_"] stringByAppendingString:apnonce] stringByAppendingString:@".shsh"] mutableCopy];
        
    }
    
    else if (strcmp(device -> product_type, "iPhone5,1") == 0 || strcmp(device -> product_type, "iPhone5,2") == 0) {
        blobname = [[[[[[[[devecid stringByAppendingString:@"_"] stringByAppendingString: devmodel] stringByAppendingString:@"_"] stringByAppendingString: board] stringByAppendingString:@"_8.4.1-12H321_"] stringByAppendingString:apnonce] stringByAppendingString:@".shsh"] mutableCopy];
    }
    irecv_close(client);
    
    NSTask *saveOTA = [[NSTask alloc]init];
    NSString *RSpath = [[NSBundle mainBundle] resourcePath];
    NSString *tsscheckerpath = [RSpath stringByAppendingString:@"/LDResources/Binaries/tsschecker"];
    saveOTA.launchPath = tsscheckerpath;
    
    
    NSString *buildmanifest = NULL;
    buildmanifest = [RSpath stringByAppendingString:@"/LDResources/Buildmanifests/"];
    buildmanifest = [buildmanifest stringByAppendingString:devmodel];
    buildmanifest = [buildmanifest stringByAppendingString:@".plist"];
    
    saveOTA.arguments = @[@"-m", buildmanifest, @"-e", devecid, @"-d", devmodel, @"-s", @"-B", board, @"--apnonce", apnonce, @"--save-path", [RSpath stringByAppendingString:@"/LDResources/SHSH"]];
    [saveOTA launch];
    [saveOTA waitUntilExit];
    
    if ([saveOTA terminationStatus] != 0) {
        return -2;
    }
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    /*
    if (strcmp(device -> product_type, "iPhone6,1") == 0 || strcmp(device -> product_type, "iPhone6,2") == 0 || strcmp(device -> product_type, "iPad4,1") == 0 || strcmp(device -> product_type, "iPad4,2") == 0 || strcmp(device -> product_type, "iPad4,3") == 0 || strcmp(device -> product_type, "iPad4,4") == 0 || strcmp(device -> product_type, "iPad4,5") == 0) {
     */
        [fm moveItemAtPath:[[RSpath stringByAppendingString:@"/LDResources/SHSH/"] stringByAppendingString:blobname]  toPath:[RSpath stringByAppendingString:@"/LDResources/SHSH/blob.shsh"] error:NULL];
   /* }
    else {
      
        NSString *newshshlocation = [[[[[RSpath stringByAppendingString:@"/LDResources/SHSH/"] stringByAppendingString:devecid] stringByAppendingString:@"-"] stringByAppendingString:devmodel] stringByAppendingString:@"-8.4.1.shsh"];
        NSString *oldshshlocation = [[RSpath stringByAppendingString:@"/LDResources/SHSH/" ] stringByAppendingString:blobname];
        [fm moveItemAtPath: oldshshlocation toPath: newshshlocation error:NULL];
    }
    */
    return 0;
}

void cleanUp(void) {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *blobLocation = [[NSString stringWithFormat:@"%@", [[NSBundle mainBundle] resourcePath]] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    if ([fileManager fileExistsAtPath: blobLocation]) {
        [fileManager removeItemAtPath:blobLocation error:NULL];
    }
    /*
        well, macOS should technincally clean the tmp path automatically but
        I don't want to risk leaving junk behind so
     */
     
    if ([fileManager fileExistsAtPath:tempipswdir]) {
        [fileManager removeItemAtPath:tempipswdir error:NULL];
    }
    
}

bool ispwned(irecv_client_t client, irecv_device_t device) {
    
    client = NULL;
    device = NULL;
    
    for (int i = 0; i < 5; i++) {
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        printf("ispwned() is attempting to connect... \n");
        if (i == 4) {
            printf("ispwned() failed to connect! \n");
            return false;
        }
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        else if (error == IRECV_E_SUCCESS){
            printf("ispwned() connected successfully! \n");
            break;
        }
    }
    irecv_devices_get_device_by_client(client, &device);
    const struct irecv_device_info *devinfo = irecv_get_device_info(client);
        
    NSString *pwnstr = [NSString stringWithFormat:@"%s", devinfo -> serial_string];
    if ([pwnstr containsString:@"PWND:[checkm8]"] || [pwnstr containsString:@"PWND:[ipwnder]"]) {
        irecv_close(client);
        return true;
    }
    else {
        irecv_close(client);
        return false;
    }
    return false;
}



const char* getDevModel(irecv_client_t client, irecv_device_t device) {

    for (int i = 0; i < 5; i++) {
        
        if (i == 4) {
            printf("getDevModel() failed to connect! \n");
            return false;
        }
        printf("getDevModel() is trying to connect... \n");
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
            if (client != NULL) {
                irecv_close(client);
                client = NULL;
            }
        }
        else {
            printf("getDevModel() connected successfully! \n");
            break;
        }
    }
    
    irecv_devices_get_device_by_client(client, &device);
    NSString *test = [NSString stringWithFormat:@"%s", device -> product_type];
    const char *devmodel = [test cStringUsingEncoding:NSASCIIStringEncoding];
    irecv_close(client);
    return devmodel;
}

NSString* getDestination(irecv_client_t client, irecv_device_t device) {

    irecv_devices_get_device_by_client(client, &device);
    
    NSString *test = [NSString stringWithFormat:@"%s", device -> product_type];
    const char *devmodel = [test cStringUsingEncoding:NSASCIIStringEncoding];
        
     if (strcmp(devmodel, "iPhone6,1") == 0 || strcmp(devmodel, "iPhone6,2") == 0 || strcmp(devmodel, "iPad4,1") == 0 || strcmp(devmodel, "iPad4,2") == 0 || strcmp("iPad4,3", devmodel) == 0 || strcmp(devmodel, "iPad4,4") == 0 || strcmp(devmodel, "iPad4,5") == 0) {
        return @"10.3.3";
    }
    
    else if (strcmp(devmodel, "iPhone5,1") == 0 || strcmp(devmodel, "iPhone5,2") == 0) {
        return @"8.4.1";
    }
    return @"how did you manage to get this messaga??";
}

bool correctIPSW(void) {
    
    NSString *plist = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW/BuildManifest.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:plist];
    NSString *stringValue=dict[@"ProductVersion"];
    const char *versionOfIPSW = [stringValue cStringUsingEncoding:NSASCIIStringEncoding];
    const char *version = [getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding];
    
    if (strcmp(version, versionOfIPSW) == 0) {
        return true;
    }
    else {
        return false;
    }
    return false;
}

bool frlog = false;

bool debugEnabled(void) {
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    NSString *stringValue=dict[@"DebugEnabled"];
    return stringValue.intValue;
}

@implementation ViewController

bool firstline = true;
bool pwned = false;


- (void) downloadiPSW:(NSString*)URL name:(NSString*)name {

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    NSURL *formattedURL = [NSURL URLWithString:URL];
    NSURLRequest *request = [NSURLRequest requestWithURL:formattedURL];
    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL *fullURL = [documentsDirectoryURL URLByAppendingPathComponent:name];
    NSString *urlns = [[NSString stringWithFormat:@"%@", fullURL] substringFromIndex:7];
    
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
            [_versionLabel setAlphaValue:0];
            [_uselessIndicator setDoubleValue:percentageCompleted];
            [_percentage setStringValue:[NSString stringWithFormat:@"%@ (%@/%@ MB)", percentageSTR, writtenSTR, totalSTR]];
        });
    }];
    
    NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {

        
        
        return fullURL;
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_uselessIndicator setUsesThreadedAnimation:NO];
            [_uselessIndicator setIndeterminate:YES];
            [_uselessIndicator startAnimation:nil];
            [self updateStatus:@"Successfully downloaded iPSW" color:[NSColor cyanColor]];
            [_percentage setStringValue:@""];
            [_versionLabel setAlphaValue:1];
            
            NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
            NSString *zipEntityToExtract = @"BuildManifest.plist";
            NSString *destinationFilePath = [tempipswdir stringByAppendingString:@"/BuildManifest.plist"];
            NSString *zipPath = urlns;
            [SSZipArchive unzipEntityName:zipEntityToExtract fromFilePath:zipPath toDestination:destinationFilePath];
          
               
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                        
                if (strcmp([getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding], "8.4.1") == 0) {
                                
                    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
                    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
                    [dict setValue: [NSString stringWithFormat:@"%@", fullURL] forKey:@"A6iPSWLocation"];
                    [dict writeToFile:preferencePlist atomically:YES];
                }
                                
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self updateStatus:[NSString stringWithFormat:@"iPSW selected at %@ and being extracted to %@", urlns, tempipswdir] color:[NSColor whiteColor]];
                    [self updateStatus:@"Extracting the iPSW please wait..." color:[NSColor greenColor]];
                });
                [SSZipArchive unzipFileAtPath:urlns toDestination: tempipswdir];
                dispatch_async(dispatch_get_main_queue(), ^(){
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[tempipswdir stringByAppendingString:@"/Firmware"]]) {
                        [self updateStatus: @"Successfully extracted the iPSW" color:[NSColor cyanColor]];
                        self -> _downgradeButtonOut.enabled = true;
                        self -> _selectIPSWoutlet.enabled = true;
                        [self->_uselessIndicator stopAnimation:nil];
                    }
                    else {
                        [self updateStatus:@"An error occured extracting the iPSW, please check your free space and try again" color:[NSColor redColor]];
                        self -> _downgradeButtonOut.enabled = false;
                        self -> _selectIPSWoutlet.enabled = true;
                        [self->_uselessIndicator stopAnimation:nil];
                    }
                });
            });
        });
    }];
    
    [downloadTask resume];
}


- (void)redirectNSLogToFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];
    freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stdout);
}


- (IBAction)dfuhelperact:(id)sender {
    
    // got this trick from Matty's Ramiel app ;)
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    NSViewController *yourViewController = [storyboard instantiateControllerWithIdentifier:@"DFUHelper"];
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self.view.window.contentViewController presentViewControllerAsSheet:yourViewController];
    });
    
}

- (IBAction)gotoSettings:(id)sender {
    
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    NSViewController *yourViewController = [storyboard instantiateControllerWithIdentifier:@"SettingsController"];
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self.view.window.contentViewController presentViewControllerAsSheet:yourViewController];
    });
}


- (int)exploitDevice:(irecv_client_t)client device:(irecv_device_t)device {
    
    client = NULL;
    device = NULL;
    
    NSString *nsdestinationFW = getDestinationFromPlist();
    const char *destinationFW = [nsdestinationFW cStringUsingEncoding:NSASCIIStringEncoding];
    
    NSTask *exploit = [[NSTask alloc] init];
    [exploit setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/iPwnder32"]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"Exploiting device..." color:[NSColor greenColor]];
    });
    if (strcmp(destinationFW, "10.3.3") == 0) {
        [exploit setArguments:@[@"-p"]];
        [exploit launch];
        [exploit waitUntilExit];
        if (ispwned(client, device)) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateStatus:@"Successfully exploited device!" color:[NSColor cyanColor]];
            });
            return 0;
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateStatus:@"Failed to exploit device, please re-enter DFU mode and try again" color:[NSColor redColor]];
                [_uselessIndicator stopAnimation:nil];
                _downgradeButtonOut.enabled = true;
                _versionLabel.alphaValue = 0;
                _versionLabel.enabled = false;
                _dfuhelpoutlet.alphaValue = 1;
                _dfuhelpoutlet.enabled = true;
            });
            return -1;
        }
    }
    
    else if (strcmp(destinationFW, "8.4.1") == 0) {
        
        [exploit setArguments:@[@"-p", @"--noibss"]];
        [exploit launch];
        [exploit waitUntilExit];
        sleep(1);
        if (ispwned(client, device)) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateStatus:@"Successfully exploited device, now uploading pwned iBSS..." color:[NSColor cyanColor]];
            });
            
            saveOTABlob(client, device);
            
            NSTask *secondpart = [[NSTask alloc] init];
            [secondpart setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/iPwnder32"]];
            [secondpart setArguments:@[@"-p"]];
            [secondpart launch];
            [secondpart waitUntilExit];
            return 0;

        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateStatus:@"Failed to exploit device, please re-enter DFU mode and try again" color:[NSColor redColor]];
                [_uselessIndicator stopAnimation:nil];
                _downgradeButtonOut.enabled = true;
                _versionLabel.alphaValue = 0;
                _versionLabel.enabled = false;
                _dfuhelpoutlet.alphaValue = 1;
                _dfuhelpoutlet.enabled = true;
            });
            return -1;
        }
    }
    else {
        printf("what are you even trying to exploit??? \n");
        return -2;
    }
    return 0;
}

-(void) writeToLogFile:(NSString*)content{
    
    content = [NSString stringWithFormat:@"%@\n",content];
    NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"LDLog.txt"];

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:fileName];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
    else {
        [content writeToFile:fileName
                  atomically:NO
                    encoding:NSStringEncodingConversionAllowLossy
                       error:nil];
    }
}

- (void)updateStatus:(NSString*)text color:(NSColor*)color1 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext = NULL;
        if (frlog) {
            logtext = @"";
        }
        else {
            if (firstline) {
                logtext = @"[+]  ";
                firstline = false;
            }
            else if (!firstline) {
                logtext = @"\n[+]  ";
            }
        }
        logtext = [logtext stringByAppendingString:text];
        NSColor *color = color1;
        NSFont* font = [NSFont fontWithName:@"Helvetica Neue" size:13.37];
     
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color, NSFontAttributeName : font};
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logtext attributes:attrs];
        [[self->_statuslabel textStorage] appendAttributedString:attrStr];
        
        [self->_statuslabel scrollRangeToVisible:NSMakeRange([[self->_statuslabel string] length], 0)];
        if (debugEnabled()) {
            [self writeToLogFile:logtext];
        }
        
    });
}

- (int) patchFiles:(BOOL)debug {
    
    if (debug) {
        [self redirectLogToDocuments];
    }
    
    irecv_client_t client = NULL;
    irecv_device_t device = NULL;
    connected = false;
   
    for (int i = 0; i < 5; i++) {
        
        if (i == 4) {
            printf("patchFiles() could not connect! \n");
            return -1;
        }
        
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        printf("patchFiles() is attempting to connect... \n");
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        if (error == IRECV_E_SUCCESS) {
            printf("patchFiles() connected successfully! \n");
            break;
        }
    }
    
    irecv_devices_get_device_by_client(client, &device);
    
    NSTask *ibsspatch = [[NSTask alloc] init];
    NSTask *ibecpatch = [[NSTask alloc] init];
    ibsspatch.launchPath = @"/usr/bin/bspatch";
    ibsspatch.arguments = @[];
    ibecpatch.launchPath = @"/usr/bin/bspatch";
    ibecpatch.arguments = @[];
    
    NSString *board = [NSString stringWithFormat:@"%s", device -> hardware_model];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    NSString *LDResourcesPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/LDResources"];
    
    irecv_close(client);
    
    if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0) {
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.iphone6.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.iphone6.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibss5s.patch"]];
        [ibsspatch launch];
        [ibsspatch waitUntilExit];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.iphone6.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.iphone6.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibec5s.patch"]];
        [ibecpatch launch];
        [ibecpatch waitUntilExit];
    }
    
    else if (strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0) {
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibss_ipad4.patch"]];
        [ibsspatch launch];
        [ibsspatch waitUntilExit];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibec_ipad4.patch"]];
        [ibecpatch launch];
        [ibecpatch waitUntilExit];
    }
    
    else if (strcmp(boardcmp, "j85ap") == 0 || strcmp(boardcmp, "j86ap") == 0) {
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4b.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4b.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibss_ipad4b.patch"]];
        [ibsspatch launch];
        [ibsspatch waitUntilExit];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4b.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4b.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibec_ipad4b.patch"]];
        [ibecpatch launch];
        [ibecpatch waitUntilExit];
        
    }
    
    int ibssstatus = [ibsspatch terminationStatus];
    int ibecstatus = [ibecpatch terminationStatus];
    
    if (ibssstatus != 0) {
        [self updateStatus:@"Error patching iBSS" color:[NSColor redColor]];
        return -1;
    }
    if (ibecstatus != 0) {
        [self updateStatus:@"Error patching iBEC" color:[NSColor redColor]];
        return -1;
    }
    return 0;
}


- (int)sendBootchain:(irecv_client_t)cli device:(irecv_device_t)dev {
    
    connected = false;
    for (int i = 0; i < 5; i++) {
        
        if (i == 4) {
            printf("sendBootchain() could not connect! \n");
            return -1;
        }
        irecv_error_t error = irecv_open_with_ecid(&cli, ecid);
        printf("sendBootchain() is attempting to connect... \n");
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        if (error == IRECV_E_SUCCESS) {
            printf("sendBootchain() connected successfully! \n");
            break;
        }
    }
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    irecv_devices_get_device_by_client(cli, &dev);
    NSString *board = [NSString stringWithFormat:@"%s", dev ->hardware_model];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    irecv_close(cli);
    if ([self sendFile:cli device:dev filename:@"/dev/null" debug:debugEnabled()] != 0) {
        return -1;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
    });
    sleep(5);
        
    if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0) {
        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBSS.iphone6.RELEASE.im4p"] debug:debugEnabled()];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
        });
        sleep(5);
        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBEC.iphone6.RELEASE.im4p"] debug:debugEnabled()];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
        });
    }
        
    else if (strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0) {
        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBSS.ipad4.RELEASE.im4p"] debug:debugEnabled()];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
        });
        sleep(5);
        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBEC.ipad4.RELEASE.im4p"] debug:debugEnabled()];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
        });
    }
    else if (strcmp(boardcmp, "j85ap") == 0 || strcmp(boardcmp, "j86ap") == 0) {
        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBSS.ipad4b.RELEASE.im4p"] debug:debugEnabled()];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
        });
        sleep(5);
        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBEC.ipad4b.RELEASE.im4p"] debug:debugEnabled()];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
        });
    }
    return 0;
}

- (void)infoLog:(NSString*)text color:(NSColor*)color1 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext;
        logtext = @"";


        logtext = [logtext stringByAppendingString:text];
        NSColor *color = color1;
        NSFont* font = [NSFont fontWithName:@"Helvetica Neue" size:13.37];
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color, NSFontAttributeName : font};
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logtext attributes:attrs];
        [[self->_statuslabel textStorage] appendAttributedString:attrStr];
        
        [self->_statuslabel scrollRangeToVisible:NSMakeRange([[self->_statuslabel string] length], 0)];
        if (debugEnabled()) {
            [self writeToLogFile:logtext];
        }
    });
}

int supported = 0;

- (int) PrintDevInfo:(irecv_client_t)tempcli device:(irecv_device_t)tempdev debug:(BOOL)debug {

    if (debug) {
        [self redirectLogToDocuments];
    }
    
    NSString *destination = getDestinationFromPlist();
    tempcli = NULL;
    tempdev = NULL;
    
    for (int i = 0; i < 5; i++) {
        irecv_error_t erro = irecv_open_with_ecid(&tempcli, ecid);
        if (i == 4) {
            printf("PrintDevInfo() failed to connect! \n");
            return -1;
        }
        printf("PrintDevInfo() is attempting to connect... \n");
        if (erro == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(erro));
        }
        else if (erro != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        else {
            printf("PrintDevInfo() connected successfully! \n");
            break;
        }
    }
    
    
    irecv_devices_get_device_by_client(tempcli, &tempdev);
    const struct irecv_device_info *devinfo = irecv_get_device_info(tempcli);
        
    NSString *stag = [NSString stringWithFormat:@"%s", devinfo -> serial_string];
    if ([stag containsString:@"PWND:[checkm8]"]) {
        pwned = true;
    }
    [self infoLog: @"\n\n============= DEVICE INFO =============\n" color:[NSColor cyanColor]];
    [self infoLog: @"\nModel Name: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s", tempdev -> display_name] color:[NSColor greenColor]];
    [self infoLog: @"\nHardware Model: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s", tempdev -> hardware_model] color:[NSColor greenColor]];
    [self infoLog: @"\nECID: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%llu", devinfo -> ecid] color:[NSColor greenColor]];
        
    [self infoLog: @"\nAPNonce:" color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%@", NSNonce(devinfo -> ap_nonce, devinfo -> ap_nonce_size)] color:[NSColor greenColor]];
    if (strcmp([destination cStringUsingEncoding:NSASCIIStringEncoding], "10.3.3") == 0) {
        [self infoLog:@"\nSEPNonce:" color:[NSColor cyanColor]];
        [self infoLog: [NSString stringWithFormat:@"%@", NSNonce(devinfo -> sep_nonce, devinfo -> sep_nonce_size)] color:[NSColor greenColor]];
    }
    [self infoLog:@"\nCPID: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%@", NSCPID(&devinfo -> cpid)] color:[NSColor greenColor]];
    [self infoLog: @"\nDestination firmware: " color:[NSColor cyanColor]];
    irecv_close(tempcli);
    [self infoLog: destination color:[NSColor greenColor]];
    [self infoLog:@"\nPwned: " color:[NSColor cyanColor]];
    if (ispwned(tempcli, tempdev)) {
        [self infoLog: @"Yes" color:[NSColor greenColor]];
    }
    else {
        [self infoLog: @"No" color:[NSColor greenColor]];
    }
    [self infoLog: @"\n\n=====================================" color:[NSColor cyanColor]];
    
    return 0;
}

- (int) sendCommand:(irecv_client_t)cli device:(irecv_device_t)dev command:(const char*)cmd debug:(bool)debug {
        
    if (debug) {
        [self redirectLogToDocuments];
    }
    
    irecv_error_t errr;
    for (int i = 0; i < 5; i++) {
        printf("sendCommand() is attempting to connect... \n");
        errr = irecv_open_with_ecid(&cli, ecid);
        if (i == 4) {
            printf("sendCommand() failed to connect! \n");
            return -1;
        }
        if (errr == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(errr));
        }
        else if (errr != IRECV_E_SUCCESS) {
        usleep(500000);
        }
        else {
            printf("sendCommand() connected successfully! \n");
            break;
        }
    }
    
    int __block ret, mode;

    printf("sencCommand() is attempting to send a file... \n");
    ret = irecv_get_mode(cli, &mode);
        
    if (ret == IRECV_E_SUCCESS) {
        irecv_devices_get_device_by_client(cli, &dev);
        irecv_send_command(cli, cmd);
    }
    irecv_close(cli);
    return 0;
}

int recursionCounter = 0;

- (int) sendFile:(irecv_client_t)client device:(irecv_device_t)device filename:(NSString*)file debug:(BOOL)debug {
    
    if (debug) {
        [self redirectLogToDocuments];
    }
    irecv_error_t error;
    int __block ret, mode;
    const char *filename = [file cStringUsingEncoding:NSASCIIStringEncoding];
    device = NULL;
    
    for (int i = 0; i < 5; i++) {
        
        if (i == 4) {
            printf("sendFile() failed to connect \n");
            dispatch_async(dispatch_get_main_queue(), ^(){
                [self updateStatus:@"sendFile() failed to connect" color:[NSColor redColor]];
            });
            return -1;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self updateStatus:@"sendFile() is attempting to connect" color:[NSColor yellowColor]];
        });
        
        printf("sendFile() is attempting to connect... \n");
        
        error = irecv_open_with_ecid(&client, ecid);
        
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
            if (client != NULL) {
                irecv_close(client);
                client = NULL;
            }
        }
        else {
            printf("sendFile() connected successfully! \n");
            break;
        }
    }
    
    ret = irecv_get_mode(client, &mode);
    
    if (ret == IRECV_E_SUCCESS) {

        error = irecv_send_file(client, filename, 1);
        if (error != IRECV_E_USB_UPLOAD && error != IRECV_E_SUCCESS) {
            if (recursionCounter < 1) {
                recursionCounter++;
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self updateStatus:[NSString stringWithFormat: @"Could not send %s, trying again once more", filename] color:[NSColor redColor]];
                });
                [self sendFile:client device:device filename:file debug:debugEnabled()];
            }
            else {
                return -2;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self updateStatus:[NSString stringWithFormat:@"Sucessfully sent %@", file] color:[NSColor cyanColor]];
        });
    }
    irecv_close(client);
    return 0;
}

bool firstrun = true;
bool newdevice = true;
unsigned long long devCompStr;

- (int) Discover:(irecv_client_t)client device:(irecv_device_t)dev {

    for (int i = 0; i < 5; i++) {
        
        if (i == 4) {
            printf("Discover() failed to connect \n");
            return -1;
        }
        printf("Discover() is attempting to connect... \n");

        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS)
            usleep(500000);
        else {
            printf("Discover() connected succesfully! \n");
            break;
        }
    }
    
    irecv_devices_get_device_by_client(client, &dev);
    const struct irecv_device_info *devinfo = irecv_get_device_info(client);
    if(!(devinfo->srtg)){
        [self updateStatus:[NSString stringWithFormat:@"Device connected in wrong mode, please put your device in DFU mode to proceed"] color:[NSColor redColor]];
            
    }
    else {
            
        dispatch_async(dispatch_get_main_queue(), ^(){
            _dfuhelpoutlet.enabled = false;
            _dfuhelpoutlet.alphaValue = 0;
            _versionLabel.enabled = true;
            _versionLabel.alphaValue = 1;
        });
            
        NSString *board = [NSString stringWithFormat:@"%s", dev ->hardware_model];
        const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
        
        if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0 || strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0 || strcmp(boardcmp, "j85ap") == 0 || strcmp(boardcmp, "j86ap") == 0 || strcmp(boardcmp, "n41ap") == 0 || strcmp(boardcmp, "n42ap") == 0)  {
                
            supported = true;
            id _Nullable destination = getDestination(client, dev);
            NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
            NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
            [dict setValue:destination forKey:@"DestinationFW"];
            [dict writeToFile:preferencePlist atomically:YES];
            dispatch_async(dispatch_get_main_queue(), ^(){
                if (strcmp([destination cStringUsingEncoding:NSASCIIStringEncoding], "8.4.1") == 0) {
                    _mainbox.fillColor = [NSColor colorWithSRGBRed:0.21f green:0.18f blue:0.24f alpha:1.0f];
                }
                else if (strcmp([destination cStringUsingEncoding:NSASCIIStringEncoding], "10.3.3") == 0) {
                    _mainbox.fillColor = [NSColor colorWithSRGBRed:0.105882352941176f green:0.305882352941176f blue:0.317647058823529f alpha:1.0f];
                }
                self -> _selectIPSWoutlet.enabled = true;
                self -> _selectIPSWoutlet.title = [NSString stringWithFormat:@"Select %@ iPSW", destination];
                
            });
                
            [self updateStatus:[NSString stringWithFormat: @"%s is supported", dev -> display_name] color:[NSColor greenColor]];
                
            irecv_close(client);
            client = NULL;
            if (firstrun) {
                [self PrintDevInfo: client device: dev debug:debugEnabled()];
                firstrun = false;
            }
        }
            
        else {
            // if we're looking at the same device, don't display this message.
            if (newdevice) {
                
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self updateStatus:[NSString stringWithFormat: @"%s is not supported", dev -> display_name] color:[NSColor redColor]];
                });
                
                devCompStr = devinfo -> ecid;
                newdevice = false;
            }
                
            if (devCompStr != devinfo -> ecid) {
                newdevice = true;
                irecv_close(client);
                return -1;
            }
                
            if (devCompStr == devinfo -> ecid) {
                irecv_close(client);
                return -1;
            }
        }
    }
    return 0;
}

/*

- (int) restoreA6:(irecv_client_t)client device:(irecv_device_t)device debug:(BOOL)debug {
    
    for (int i = 0; i < 5; i++) {
        
        if (i == 4) {
            printf("restoreA6 failed to connect! \n");
            return -1;
        }
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        printf("restoreA6 is attempting to connect... \n");
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        if (error == IRECV_E_SUCCESS) {
            printf("restoreA6 connected successfully! \n");
            break;
        }
    }
    
    irecv_devices_get_device_by_client(client, &device);
            
    NSString *devmodel = [NSString stringWithFormat:@"%s", device ->product_type];
    NSString *board = [NSString stringWithFormat:@"%s", device ->hardware_model];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    
    NSTask *restore = [[NSTask alloc]init];
    restore.launchPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/futurerestorefu"];
    restore.arguments = @[];
    NSString *bm =[[[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/BuildManifests/"] stringByAppendingString:[NSString stringWithFormat:@"%@", devmodel]] stringByAppendingString:@".plist"];
    NSString *bb = [tempipswdir stringByAppendingString:@"/Firmware/Mav5-8.02.00.Release.bbfw"];
    NSString *ticket = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
    
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    NSString *ipsw=dict[@"A6iPSWLocation"];
    
    if (strcmp(boardcmp, "n41ap") == 0 || strcmp(boardcmp, "n42ap") == 0) {
        
        restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"--use-pwndfu", ipsw];
    }
    
    irecv_close(client);
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self updateStatus:@"Starting restore process in 5 seconds\n" color:[NSColor greenColor]];
    });
    sleep(5);
    __block int i = 0;
        
    if (debugEnabled()) {
        // from https://stackoverflow.com/a/23938137
        __block bool cool = true;
        __block bool firstPart = true;
        frlog = true;
        NSPipe *stdoutPipe = [NSPipe pipe];
        [restore setStandardOutput:stdoutPipe];
        NSFileHandle *stdoutHandle = [stdoutPipe fileHandleForReading];
        [stdoutHandle waitForDataInBackgroundAndNotify];
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification
                                                                        object:stdoutHandle queue:nil
                                                                    usingBlock:^(NSNotification *note)
        {
            // This block is called when output from the task is available.

            NSData *dataRead = [stdoutHandle availableData];
            NSString *stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
            
            dispatch_async(dispatch_get_main_queue(), ^() {
                [self updateStatus:stringRead color:[NSColor whiteColor]];
            });

            if ([stringRead containsString:@"%"]) {
                
                if (firstPart) {
                    
                    cool = false;
                    
                    dispatch_async(dispatch_get_main_queue(), ^(){
                
                    
                        if (i == 0) {
                            i++;
                            _uselessIndicator.indeterminate = false;
                            _uselessIndicator.doubleValue = 0;
                            _uselessIndicator.maxValue = 100;
                            [self updateStatus:@"Sending filesystem\n" color:[NSColor greenColor]];
                        }
                       
                        if (_uselessIndicator.doubleValue == 100) {
                            [self updateStatus:@"Verifying filesystem\n" color:[NSColor greenColor]];
                            _uselessIndicator.doubleValue = 0;
                            _uselessIndicator.maxValue = 50;
                        }
                        
                        [self -> _uselessIndicator incrementBy:1];
                    
                    });
                }
            }
            
            if ([stringRead containsString:@"About to send KernelCache..."]) {
                firstPart = false;
            }
            
            if ([stringRead containsString:@"Checking filesystems (15)"]) {
                cool = true;
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self -> _uselessIndicator setUsesThreadedAnimation:NO];
                    [self -> _uselessIndicator setIndeterminate:YES];
                    [self -> _uselessIndicator startAnimation:nil];
                });
            }
            
            if (cool) {
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self updateStatus:stringRead color:[NSColor whiteColor]];
                });
            }
 
            [stdoutHandle waitForDataInBackgroundAndNotify];
        }];
    }
    
    [restore launch];
    [restore waitUntilExit];
    return [restore terminationStatus];

}
*/
- (int) restore64:(irecv_client_t)client device:(irecv_device_t)device debug:(BOOL)debug {

    client = NULL;
    device = NULL;
    connected = false;
    if ([self patchFiles:debugEnabled()] != 0) {
        [self updateStatus:@"Error patching bootchain" color:[NSColor redColor]];
        return -1;
    }
    
    if ([self sendBootchain:client device:device] != 0) {
        [self updateStatus:@"Error sending bootchain" color:[NSColor redColor]];
        return -1;
    }
    
    sleep(1);
    
    for (int i = 0; i < 5; i++) {
        
        if (i == 4) {
            printf("restore64 failed to connect! \n");
            return -1;
        }
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        printf("restore64 is attempting to connect... \n");
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        if (error == IRECV_E_SUCCESS) {
            printf("restore64 connected successfully! \n");
            break;
        }
    }
    
    irecv_devices_get_device_by_client(client, &device);
            
    NSString *devmodel = [NSString stringWithFormat:@"%s", device ->product_type];
    NSString *board = [NSString stringWithFormat:@"%s", device ->hardware_model];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    
    NSTask *restore = [[NSTask alloc]init];
    restore.launchPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/futurerestore"];
    restore.arguments = @[];
    NSString *iPhoneBootLogo = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Bootlogos/5s.img4"];
    NSString *iPadBootLogo = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Bootlogos/ipad.img4"];
    const char *iPhoneLDBoot = [iPhoneBootLogo cStringUsingEncoding:NSASCIIStringEncoding];
    const char *iPadLDBoot = [iPadBootLogo cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *bm =[[[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/BuildManifests/"] stringByAppendingString:[NSString stringWithFormat:@"%@", devmodel]] stringByAppendingString:@".plist"];
    NSString *bb = [tempipswdir stringByAppendingString:@"/Firmware/Mav7Mav8-7.60.00.Release.bbfw"];
    NSString *sep = [[tempipswdir stringByAppendingString:@"/Firmware/all_flash/sep-firmware."] stringByAppendingString: [NSString stringWithFormat:@"%s", device -> hardware_model]];
    sep = [sep substringToIndex:[sep length] -2];
    sep = [sep stringByAppendingString:@".RELEASE.im4p"];
    NSString *ticket = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
    
    
    if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0) {
        
        irecv_send_file(client, iPhoneLDBoot, 1);
        irecv_send_command(client, "setpicture 0");
        
        restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"-m", bm, @"-s", sep, tempipswdir];
    }

    else if (strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j85ap") == 0) {
        
        irecv_send_file(client, iPadLDBoot, 1);
        irecv_send_command(client, "setpicture 0");
        
        restore.arguments = @[@"-t", ticket, @"-p", bm, @"-m", bm, @"-s", sep, tempipswdir, @"-d", @"--no-baseband"];
        
    }
    else if (strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0 || strcmp(boardcmp, "j86ap") == 0 || strcmp(boardcmp, "j87ap") == 0) {
        
        irecv_send_file(client, iPadLDBoot, 1);
        irecv_send_command(client, "setpicture 0");
        
        restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"-m", bm, @"-s", sep, @"-d", tempipswdir];
        
    }
    sleep(1);
    irecv_send_command(client, "bgcolor 254 254 254");
    irecv_close(client);
    sleep(5);
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self updateStatus:@"Starting restore process" color:[NSColor greenColor]];
    });

    NSPipe * out = [NSPipe pipe];
    [restore setStandardOutput:out];

    [restore launch];
    [restore waitUntilExit];
    
    if (debugEnabled()) {
        
        NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        NSString *LDloglocation = [documentsDirectory stringByAppendingPathComponent:@"LDLog.txt"];

        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:LDloglocation];
        [fileHandle seekToEndOfFile];
        
        NSFileHandle * read = [out fileHandleForReading];
        NSData * dataRead = [read readDataToEndOfFile];
        NSString * stringRead = [[[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding] autorelease];
        [fileHandle writeData:[stringRead dataUsingEncoding:NSUTF8StringEncoding]];
        NSLog(@"output: %@", stringRead);
        
        [fileHandle closeFile];
        
    }
    
    
    return [restore terminationStatus];
}


- (IBAction)selectIPSW:(id)sender {
    
    if (debugEnabled()) {
        [self redirectLogToDocuments];
    }
    
    cleanUp();
    irecv_client_t client = NULL;
    irecv_device_t device = NULL;
    
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Select iPSW"];
    [alert setInformativeText:@"Would you like to browse for an iPSW or let LeetDown download the correct one for your device? A copy of the iPSW will be saved to your Documents folder"];
    [alert addButtonWithTitle:@"Download an iPSW"];
    [alert addButtonWithTitle:@"Browse for an iPSW"];
    [alert setAlertStyle:NSAlertStyleWarning];

    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        
        if (returnCode == NSAlertFirstButtonReturn) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                const char *devmodel = getDevModel(client, device);
                NSString *ipswname = [[[[NSString stringWithFormat:@"%s", devmodel] stringByAppendingString: @"_"] stringByAppendingString:getDestinationFromPlist()] stringByAppendingString:@"_stock.ipsw"];
                NSString *ipswLocation = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingString:@"/"] stringByAppendingString:ipswname];
                if ([[NSFileManager defaultManager] fileExistsAtPath:ipswLocation]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateStatus:[NSString stringWithFormat: @"You already have an iPSW in your Documents folder named \"%@\". Either delete that iPSW or specify it by clicking \"Browse for an iPSW\".", ipswname] color:[NSColor redColor]];
                    });
                }
                else {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _selectIPSWoutlet.enabled = false;
                        _percentage.stringValue = @"%0";
                        [self infoLog:@"\n" color:[NSColor whiteColor]];
                        [self updateStatus:[NSString stringWithFormat:@"Downloading iOS %@ iPSW for %s...", getDestinationFromPlist(), devmodel] color:[NSColor greenColor]];
                        [_uselessIndicator setIndeterminate:NO];
                        [_uselessIndicator setMaxValue:1];
                    });
                    
                    if (strcmp(devmodel, "iPhone6,1" ) == 0 || strcmp(devmodel, "iPhone6,2" ) == 0) {
                        [self downloadiPSW:@"http://appldnld.apple.com/ios10.3.3/091-23133-20170719-CA8E78E6-6977-11E7-968B-2B9100BA0AE3/iPhone_4.0_64bit_10.3.3_14G60_Restore.ipsw" name:ipswname];
                    }
                    else if (strcmp(devmodel, "iPad4,1" ) == 0 || strcmp(devmodel, "iPad4,2" ) == 0 || strcmp(devmodel, "iPad4,3" ) == 0 || strcmp(devmodel, "iPad4,4" ) == 0 || strcmp(devmodel, "iPad4,5" ) == 0) {
                        [self downloadiPSW:@"http://appldnld.apple.com/ios10.3.3/091-23378-20170719-CA983C78-6977-11E7-8922-3D9100BA0AE3/iPad_64bit_10.3.3_14G60_Restore.ipsw" name:ipswname];
                    }
                    else if (strcmp(devmodel, "iPhone5,1") == 0 ) {
                        [self downloadiPSW:@"http://appldnld.apple.com/ios8.4.1/031-31186-20150812-751D243C-3C8F-11E5-8E4F-B51A3A53DB92/iPhone5,1_8.4.1_12H321_Restore.ipsw" name:ipswname];
                    }
                    else if (strcmp(devmodel, "iPhone5,2") == 0 ) {
                        [self downloadiPSW:@"http://appldnld.apple.com/ios8.4.1/031-31065-20150812-7518F132-3C8F-11E5-A96A-A11A3A53DB92/iPhone5,2_8.4.1_12H321_Restore.ipsw" name:ipswname];
                    }
                }
            });
        }
        else {
            
            NSOpenPanel* openDlg = [NSOpenPanel openPanel];
            NSArray* fileTypes = [NSArray arrayWithObjects:@"ipsw", @"IPSW", nil];
            [openDlg setCanChooseFiles:YES];
            [openDlg setCanChooseDirectories:YES];
            [openDlg setAllowedFileTypes:fileTypes];

            if ( [openDlg runModal] == NSModalResponseOK ) {
                
                for( NSURL* URL in [openDlg URLs] ) {

                    NSString *filepath = URL.absoluteString;
                    filepath = [filepath substringFromIndex:7];
                    [[NSFileManager defaultManager] createDirectoryAtPath:tempipswdir withIntermediateDirectories:NO attributes:NULL error:NULL];
                    
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        self -> _downgradeButtonOut.enabled = false;
                        self -> _selectIPSWoutlet.enabled = false;
                        [self updateStatus:@"Verifying iPSW" color:[NSColor greenColor]];
                        _uselessIndicator.indeterminate = true;
                        
                        NSString *zipEntityToExtract = @"BuildManifest.plist";
                        NSString *destinationFilePath = [tempipswdir stringByAppendingString:@"/BuildManifest.plist"];
                        NSString *zipPath = filepath;
                        [SSZipArchive unzipEntityName:zipEntityToExtract fromFilePath:zipPath toDestination:destinationFilePath];

                        if (correctIPSW()) {
                            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                                
                                dispatch_async(dispatch_get_main_queue(), ^(){
                                    [self updateStatus:@"Successfully verified the iPSW" color:[NSColor cyanColor]];
                                });
                                if (strcmp([getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding], "8.4.1") == 0) {
                                        
                                    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
                                    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
                                    [dict setValue: filepath forKey:@"A6iPSWLocation"];
                                    [dict writeToFile:preferencePlist atomically:YES];
                                }
                                        
                                dispatch_async(dispatch_get_main_queue(), ^(){
                                    [self updateStatus:[NSString stringWithFormat:@"iPSW selected at %@ and being extracted to %@", filepath, tempipswdir] color:[NSColor whiteColor]];
                                    [self updateStatus:@"Extracting the iPSW please wait..." color:[NSColor greenColor]];
                                    [self->_uselessIndicator startAnimation:nil];
                                });
                                [SSZipArchive unzipFileAtPath:filepath toDestination: tempipswdir];
                                dispatch_async(dispatch_get_main_queue(), ^(){
                                    if ([[NSFileManager defaultManager] fileExistsAtPath:[tempipswdir stringByAppendingString:@"/Firmware"]]) {
                                        [self updateStatus: @"Successfully extracted the iPSW" color:[NSColor cyanColor]];
                                        self -> _downgradeButtonOut.enabled = true;
                                        self -> _selectIPSWoutlet.enabled = true;
                                        [self->_uselessIndicator stopAnimation:nil];
                                    }
                                    else {
                                        [self updateStatus:@"An error occured extracting the iPSW, please check your free space and try again" color:[NSColor redColor]];
                                        self -> _downgradeButtonOut.enabled = false;
                                        self -> _selectIPSWoutlet.enabled = true;
                                        [self->_uselessIndicator stopAnimation:nil];
                                    }
                                });
                            });
                        }
                        else {
                            [self updateStatus:@"Destination firmware does not match with the selected iPSW" color:[NSColor redColor]];
                            self -> _downgradeButtonOut.enabled = false;
                            self -> _selectIPSWoutlet.enabled = true;
                        }
                    });
                }
            }
        }
    }];
}

- (IBAction)downgradeButtonAct:(id)sender {
    
    if (debugEnabled()) {
        [self redirectLogToDocuments];
    }
    
    irecv_device_t dev = NULL;
    irecv_client_t cli = NULL;
    
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Warning"];
    [alert setInformativeText:@"Downgrading your device will erase all the data on it"];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSAlertStyleWarning];

    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        
        if (returnCode == NSAlertFirstButtonReturn) {
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self -> _uselessIndicator startAnimation:nil];
                    _dfuhelpoutlet.enabled = false;
                    _dfuhelpoutlet.alphaValue = 0;
                    _selectIPSWoutlet.enabled = false;
                    _downgradeButtonOut.enabled = false;
                    _versionLabel.alphaValue = 1;
                });
                sleep(1);
                if (pwned) {
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        [self updateStatus:@"Device was already pwned, skipping exploitation" color:[NSColor cyanColor]];
                    });
                }
                
                else {
                    
                    if ([self exploitDevice:cli device:dev] != 0) {
                        return;
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self updateStatus:@"Fetching OTA blob" color:[NSColor greenColor]];
                });
                    
  
                if (saveOTABlob(cli, dev) == -2) {
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        [self updateStatus:[NSString stringWithFormat:@"Failed to save %s OTA blob. Is it being signed?", [getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding]] color:[NSColor redColor]];
                    });
                }
                else {
                
                    
                dispatch_async(dispatch_get_main_queue(), ^(){
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert setMessageText:@"Backup your blob"];
                    [alert setInformativeText:@"Would you like to backup your SHSH blob? By backing up your blob, you will be able to downgrade to OTA firmwares with LeetDown even if Apple decides to unsign them someday."];
                    [alert addButtonWithTitle:@"Yes"];
                    [alert addButtonWithTitle:@"Skip"];
                    [alert setAlertStyle:NSAlertStyleWarning];

                    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
                        if (returnCode == NSAlertFirstButtonReturn) {
                            NSString *bloblocation = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
                            NSSavePanel *panel = [NSSavePanel savePanel];
                            [panel setMessage:@"Please select a location to save SHSH blob."];
                            [panel setAllowsOtherFileTypes:YES];
                            [panel setExtensionHidden:NO];
                            [panel setCanCreateDirectories:YES];
                            [panel setTitle:@"Save your blob"];
                            [panel setNameFieldStringValue:@"(give a name to your blob)"];
                            [panel beginWithCompletionHandler:^(NSInteger result) {
                                
                                if (result == NSModalResponseOK) {
                                    NSString *path = [[panel URL] path];
                                    NSURL *saveLocation = [NSURL fileURLWithPath:path];
                                    NSURL *a = [NSURL fileURLWithPath:bloblocation];
                                    NSError *e = nil;
                                    [[NSFileManager defaultManager] copyItemAtURL:a toURL:saveLocation error:&e];
                                    [self updateStatus: [NSString stringWithFormat:@"Saved blob to %@. Keep it safe!", saveLocation] color:[NSColor cyanColor]];
                                    
                                }
                                else {
                                    [self updateStatus:@"Skipped saving a copy of the blob" color:[NSColor yellowColor]];
                                }
                                
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                    
                                    if (strcmp([getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding], "10.3.3") == 0) {
                                            
                                        if ([self restore64:cli device:dev debug:debugEnabled()] == 0) {
                                            dispatch_async(dispatch_get_main_queue(), ^(){
                                                [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                                [self -> _uselessIndicator stopAnimation:nil];
                                                _selectIPSWoutlet.enabled = true;
                                                
                                            });
                                        }
                                    }
                                    
                                    /*
                                    else if (strcmp([getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding], "8.4.1") == 0) {
                                            
                                        if ([self restoreA6:cli device:dev debug:debugEnabled()] == 0) {
                                            dispatch_async(dispatch_get_main_queue(), ^(){
                                                [self -> _uselessIndicator stopAnimation:nil];
                                                [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                                _selectIPSWoutlet.enabled = true;
                                            });
                             
                                        }
                                    }
                                     */
                                        
                                    else {
                                        dispatch_async(dispatch_get_main_queue(), ^(){
                                            [self -> _uselessIndicator stopAnimation:nil];
                                            [self updateStatus:@"Failed to restore device" color:[NSColor redColor]];
                                        });
                                        return;
                                    }
                                });
                            }];
                        }
                        else {
                            [self updateStatus:@"Skipped saving a copy of the blob" color:[NSColor yellowColor]];
                            
                            
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            
                                if (strcmp([getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding], "10.3.3") == 0) {
                                    dispatch_async(dispatch_get_main_queue(), ^(){
                                        [self updateStatus:@"Sending bootchain" color:[NSColor greenColor]];
                                    });
                                    if ([self restore64:cli device:dev debug:debugEnabled()] == 0) {
                                        dispatch_async(dispatch_get_main_queue(), ^(){
                                            [self -> _uselessIndicator stopAnimation:nil];
                                            [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                            _selectIPSWoutlet.enabled = true;
                                        });
                         
                                    }
                                    else {
                                        dispatch_async(dispatch_get_main_queue(), ^(){
                                            [self -> _uselessIndicator stopAnimation:nil];
                                            [self updateStatus:@"Restore failed" color:[NSColor redColor]];
                                            _selectIPSWoutlet.enabled = true;
                                        });
                                    }
                                }
                                /*
                                else if (strcmp([getDestinationFromPlist() cStringUsingEncoding:NSASCIIStringEncoding], "8.4.1") == 0) {
                                    
                                        
                                    if ([self restoreA6:cli device:dev debug:debugEnabled()] == 0) {
                                        dispatch_async(dispatch_get_main_queue(), ^(){
                                            [self -> _uselessIndicator stopAnimation:nil];
                                            [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                            _selectIPSWoutlet.enabled = true;
                                        });
                                    }
                                    else {
                                        dispatch_async(dispatch_get_main_queue(), ^(){
                                            [self -> _uselessIndicator stopAnimation:nil];
                                            [self updateStatus:@"Restore failed" color:[NSColor redColor]];
                                            _selectIPSWoutlet.enabled = true;
                                        });
                                    }
                                }
                                 */
                            });
                        }
                    }];
                });
            }
            });
        }
        else if (returnCode == NSAlertSecondButtonReturn) {
            [self updateStatus:@"Restore was cancelled by user" color:[NSColor yellowColor]];
            return;
        }
    }];
}
bool dryRun = true;

- (void)redirectLogToDocuments {
     NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
     NSString *documentsDirectory = [allPaths objectAtIndex:0];
     NSString *pathForLog = [documentsDirectory stringByAppendingPathComponent:@".txt"];
     freopen([pathForLog cStringUsingEncoding:NSASCIIStringEncoding],"a+",stdout);
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _versionLabel.enabled = false;
    _versionLabel.alphaValue = 0;
    NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *fileName = [documentsDirectory stringByAppendingPathComponent:@"LDLog.txt"];
    
    if (dryRun) {
        dryRun = false;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fileName]) {
            [[NSFileManager defaultManager] removeItemAtPath:fileName error:nil];
        }
    }
    
    cleanUp();
    [_uselessIndicator setHidden:NO];
    [_uselessIndicator setIndeterminate:YES];
    [_uselessIndicator setUsesThreadedAnimation:YES];
    NSProcessInfo *pInfo = [NSProcessInfo processInfo];
    NSString *version = [pInfo operatingSystemVersionString];
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    char *model = nil;
    if (len) {
        model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
    }
    [self updateStatus:[NSString stringWithFormat:@"Running on %s on %@", model, version] color:[NSColor whiteColor]];
    [self updateStatus:@"Waiting for a device in DFU Mode" color:[NSColor greenColor]];
    int randNum = arc4random_uniform(1000000);
    if (randNum == 0) {
        _header.stringValue = @"🗿";
        _ramiel.stringValue = @"Okay Ramiel did it first but you have one in a million chance of seeing\n this Moyai";
    }
    irecv_device_t tempdev = NULL;
    irecv_client_t tempcli = NULL;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!supported) {
            
            if (debugEnabled()) {
                [self redirectLogToDocuments];
            }
            [self Discover: tempcli device: tempdev];
            
            usleep(500000);
        }
        irecv_close(tempcli);
    });
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

@end
