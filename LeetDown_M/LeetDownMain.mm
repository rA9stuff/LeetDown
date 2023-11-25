#import "LeetDownMain.h"
#include "LDD.h"
#include "PlistUtils.h"
#include "USBUtils.h"
#include "NormalModeOperations.h"
#include "UpdateController.h"
#define USB_TIMEOUT 10000

extern BOOL LD_signalReceived;
extern NSCondition *LD_conditionVariable;
USBUtils* USB_VC = [[USBUtils alloc] init];

NSString* NSCPID(const unsigned int *buf) {
    NSMutableString *mstr=[[NSMutableString alloc] init];
    [mstr appendFormat:@"%04x", buf[0]];
    return mstr;
}

NSString* NSNonce(unsigned char *buf, size_t len) {
    NSMutableString *nonce=[[NSMutableString alloc] init];
    for (int i = 0; i < len; i++) {
        [nonce appendFormat:@"%02x", buf[i]];
    }
    return nonce;
}

void cleanUp(void) {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *blobLocation = [[NSString stringWithFormat:@"%@", [[NSBundle mainBundle] resourcePath]] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    
    if ([fileManager fileExistsAtPath: blobLocation]) {
        [fileManager removeItemAtPath:blobLocation error:NULL];
    }
     
    if ([fileManager fileExistsAtPath:tempipswdir]) {
        [fileManager removeItemAtPath:tempipswdir error:NULL];
    }
}

@implementation ViewController

bool pwned = false;
bool restoreStarted = false;
double uzip_progress = 0;
NSString *ECID = NULL;
bool discoverStateEnded = false;

LDD *dfuDevPtr = new LDD; // initialize it with defualt constructor first, since we only need ECID not to be NULL to connect to device

- (void)startMonitoringStdout {
    setbuf(stdout, NULL);
    NSPipe* pipe = [NSPipe pipe];
    NSFileHandle* pipeReadHandle = [pipe fileHandleForReading];
    dup2([[pipe fileHandleForWriting] fileDescriptor], fileno(stdout));
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_event_handler(source, ^{
        void* data = malloc(4096);
        ssize_t readResult = 0;
        do {
            errno = 0;
            readResult = read([pipeReadHandle fileDescriptor], data, 4096);
        } while (readResult == -1 && errno == EINTR);
        
        if (readResult > 0) {
            dispatch_async(dispatch_get_main_queue(),^{
                NSString *stdOutString = [[NSString alloc] initWithBytesNoCopy:data length:readResult encoding:NSUTF8StringEncoding freeWhenDone:YES];
                
                // beautify ipwnder_lite output
                NSColor* outputcolor = [NSColor whiteColor];
                
                if ([stdOutString containsString:@"[31m"]) {
                    outputcolor = [NSColor redColor];
                }
                else if ([stdOutString containsString:@"[32m"]) {
                    outputcolor = [NSColor greenColor];
                }
                stdOutString = [[[stdOutString stringByReplacingOccurrencesOfString:@"[31m" withString:@""]
                                        stringByReplacingOccurrencesOfString:@"[32m" withString:@""]
                                        stringByReplacingOccurrencesOfString:@"[39m" withString:@""];

                [self infoLog:stdOutString color:outputcolor];
            });
        }
        else {
            free(data);
        }
        fflush(stdout);
    });
    dispatch_resume(source);
}


- (unsigned long long)fileSizeAtPath:(NSString *)filePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[filePath substringFromIndex:6] error:&error];
    
    if (error || !fileAttributes) {
        // Error retrieving file attributes
        return 0;
    }
    
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    
    if (!fileSizeNumber) {
        // File size attribute not found
        return 0;
    }
    
    return [fileSizeNumber unsignedLongLongValue];
}


- (const char*) ipswVersion:(NSString*)ipswPath {
    
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    NSString *zipEntityToExtract = @"BuildManifest.plist";
    NSString *destinationFilePath = [tempipswdir stringByAppendingString:@"/BuildManifest.plist"];
    [SSZipArchive unzipEntityName:zipEntityToExtract fromFilePath:ipswPath toDestination:destinationFilePath];
    
    NSString *ipswBM = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW/BuildManifest.plist"];
    NSDictionary *ipswDict=[[NSDictionary alloc] initWithContentsOfFile:ipswBM];
    NSString *versionStringValue=ipswDict[@"ProductVersion"];
    const char *versionOfIPSW = [versionStringValue cStringUsingEncoding:NSASCIIStringEncoding];
    return versionOfIPSW;
}

- (int) iPSWcheck:(NSURL*) ipswLocation {
    NSString *sizeCheckValue;
    NSString* cpid = NSCPID(&dfuDevPtr -> getDevInfo() -> cpid);
    if (strcmp(cpid.UTF8String, "8960") != 0 && strcmp(cpid.UTF8String, "8965") != 0) {
        sizeCheckValue = [[NSString stringWithFormat:@"%s", dfuDevPtr -> getProductType()] stringByAppendingString:@"Size"];
    }
    else if (strcmp(dfuDevPtr -> getProductType(), "iPhone6,1") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPhone6,2") == 0) {
        sizeCheckValue = @"iPhone64Size";
    }
    else {
        sizeCheckValue = @"iPad64Size";
    }

    NSString* result = [NSString stringWithFormat:@"%llu", [self fileSizeAtPath:ipswLocation.absoluteString]];
    if (![result isEqualToString: getPref(sizeCheckValue)]) {
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self updateStatus:@"iPSW is corrupt! If you think this is a mistake, disable iPSW check in settings" color:[NSColor redColor]];
            self -> _selectIPSWoutlet.enabled = true;
        });
        return -1;
    }
    return 0;
}

- (int) saveOTABlob {
    
    NSMutableString *blobname = NULL;
    
    NSString *devecid = [NSString stringWithFormat:@"%llu", dfuDevPtr -> getDevInfo() -> ecid];
    NSString *devmodel = [NSString stringWithFormat:@"%s", dfuDevPtr -> getProductType()];
    NSString *apnonce = [NSString stringWithFormat:@"%@", NSNonce(dfuDevPtr -> getDevInfo() -> ap_nonce, dfuDevPtr -> getDevInfo() -> ap_nonce_size)];
    NSString *board = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    if (strcmp(dfuDevPtr -> getProductType(), "iPhone6,1") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPhone6,2") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPad4,1") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPad4,2") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPad4,3") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPad4,4") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPad4,5") == 0) {
        
        blobname = [[[[[[[[devecid stringByAppendingString:@"_"] stringByAppendingString: devmodel] stringByAppendingString:@"_"] stringByAppendingString: board] stringByAppendingString:@"_10.3.3-14G60_"] stringByAppendingString:apnonce] stringByAppendingString:@".shsh"] mutableCopy];
    }
    else {
        blobname = [[[[[[[[devecid stringByAppendingString:@"_"] stringByAppendingString: devmodel] stringByAppendingString:@"_"] stringByAppendingString: board] stringByAppendingString:@"_8.4.1-12H321_"] stringByAppendingString:apnonce] stringByAppendingString:@".shsh"] mutableCopy];
    }
    
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
    [fm moveItemAtPath:[[RSpath stringByAppendingString:@"/LDResources/SHSH/"] stringByAppendingString:blobname]  toPath:[RSpath stringByAppendingString:@"/LDResources/SHSH/blob.shsh"] error:NULL];

    return 0;
}

- (void) downloadiPSW:(NSString*)URL name:(NSString*)name {

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    NSURL *formattedURL = [NSURL URLWithString:URL];
    NSURLRequest *request = [NSURLRequest requestWithURL:formattedURL];
    NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL *fullURL = [documentsDirectoryURL URLByAppendingPathComponent:name];
    
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
        }
                                              
        completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_uselessIndicator setUsesThreadedAnimation:NO];
            [_uselessIndicator setIndeterminate:YES];
            [_uselessIndicator startAnimation:nil];
            [self updateStatus:@"Successfully downloaded iPSW" color:[NSColor cyanColor]];
            [_percentage setStringValue:@""];
            [_versionLabel setAlphaValue:1];
            
            
        });
    }];
    
    [downloadTask resume];
}

- (void)extractIPSW:(NSURL*)filePath {
    
    NSString *urlns = [[NSString stringWithFormat:@"%@", filePath] substringFromIndex:7];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    NSString *zipEntityToExtract = @"BuildManifest.plist";
    NSString *destinationFilePath = [tempipswdir stringByAppendingString:@"/BuildManifest.plist"];
    NSString *zipPath = urlns;
    [SSZipArchive unzipEntityName:zipEntityToExtract fromFilePath:zipPath toDestination:destinationFilePath];
  
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                        
        dispatch_async(dispatch_get_main_queue(), ^(){
            [[self dfuhelpoutlet] setHidden:TRUE];
            [[self dfuhelpoutlet] setEnabled:false];
            [self updateStatus:[NSString stringWithFormat:@"iPSW selected at %@ and being extracted to %@", urlns, tempipswdir] color:[NSColor whiteColor]];
            [self updateStatus:@"Extracting the iPSW" color:[NSColor greenColor]];
            [self->_uselessIndicator setIndeterminate:NO];
        });
        [SSZipArchive unzipFileAtPath:urlns toDestination:tempipswdir progressHandler:^(NSString *entry, unz_file_info zipInfo, long entryNumber, long total) {
            
            dispatch_async(dispatch_get_main_queue(), ^(){
                __block NSString *percentageStr = [NSString stringWithFormat:@"%f", uzip_progress];
                percentageStr = [percentageStr substringToIndex:[percentageStr length] -4];
                percentageStr = [percentageStr substringFromIndex:2];
                [_percentage setStringValue:[NSString stringWithFormat:@"%@%%", percentageStr]];
                [self -> _uselessIndicator setDoubleValue:uzip_progress];
            });
        } completionHandler:^(NSString *path, BOOL succeeded, NSError* err) {
            
            dispatch_async(dispatch_get_main_queue(), ^(){
                if (succeeded) {
                    [self updateStatus: @"Successfully extracted the iPSW" color:[NSColor cyanColor]];
                    [self -> _versionLabel setAlphaValue:1.0];
                    [self -> _uselessIndicator setHidden:YES];
                    self -> _percentage.hidden = true;
                    self -> _versionLabel.hidden = false;
                    self -> _downgradeButtonOut.enabled = true;
                    self -> _selectIPSWoutlet.enabled = true;
                    [self->_uselessIndicator stopAnimation:nil];
                    
                    modifyPref(@"32iPSWLoc", tempipswdir);
                }
                else {
                    [self updateStatus:@"An error occured extracting the iPSW, please check your free space and try again" color:[NSColor redColor]];
                    self -> _downgradeButtonOut.enabled = false;
                    self -> _selectIPSWoutlet.enabled = true;
                    [self->_uselessIndicator stopAnimation:nil];
                }
            });
        }];
    });
}

- (void)verifyIPSW:(NSString*)filepath {
    
    
    
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
    NSViewController *yourViewController = [storyboard instantiateControllerWithIdentifier:@"UpdateController"];
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self.view.window.contentViewController presentViewControllerAsSheet:yourViewController];
    });
}


- (int)exploitDevice {
    
    int exploitIndex = getPref(@"exploit_index").intValue;
    NSString *exploitName = NULL;
    
    switch (exploitIndex) {
        case 0:
            exploitName = @"iPwnder32";
            break;
        case 1:
            exploitName = @"ipwnder_lite";
            break;
        case 2:
            exploitName = @"gaster";
            break;
        default:
            break;
    }
    
    if (exploitName == NULL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:[NSString stringWithFormat:@"Invalid exploit index: %i, unable to continue.", exploitIndex] color:[NSColor greenColor]];
        });
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:[NSString stringWithFormat:@"Pwning device with %@...", exploitName] color:[NSColor greenColor]];
    });
    
    checkm8_32_exploit(dfuDevPtr -> getClient(), dfuDevPtr -> getDevice(), dfuDevPtr -> getDevInfo());
    
    /*
    sleep(1);
    NSTask *exploit = [[NSTask alloc] init];
    [exploit setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/ipwnder_macosx"]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"Exploiting device..." color:[NSColor greenColor]];
    });

    [exploit setArguments:@[@"-p"]];
    [exploit setCurrentDirectoryPath: [NSString stringWithFormat: @"%@/LDResources", [[NSBundle mainBundle] resourcePath]]];
    [exploit launch];
    [exploit waitUntilExit];

    sleep(1);
    if (!dfuDevPtr -> checkPwn()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Exploit failed, please re-enter DFU mode to try again" color:[NSColor redColor]];
            [_uselessIndicator stopAnimation:nil];
            _downgradeButtonOut.enabled = true;
            _versionLabel.alphaValue = 0.0;
            _versionLabel.enabled = false;
            _dfuhelpoutlet.alphaValue = 1.0;
            _dfuhelpoutlet.enabled = true;
        });
        return -1;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"Exploit succeeded!" color:[NSColor cyanColor]];
    });
    
    // we want to minimize the # of times we connect to devices for stability reasons
    // so, get the info from the plist instead.
    
    if (strcmp(getPref(@"destinationFW").UTF8String, "8.4.1") == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Uploading pwned iBoot..." color:[NSColor cyanColor]];
        });
        NSTask *iBootUpload = [[NSTask alloc] init];
        [iBootUpload setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/ipwnder_macosx"]];
        [iBootUpload setArguments:@[@"--upload-iboot"]];
        [iBootUpload setCurrentDirectoryPath: [NSString stringWithFormat: @"%@/LDResources", [[NSBundle mainBundle] resourcePath]]];
        [iBootUpload launch];
        [iBootUpload waitUntilExit];
        sleep(1);
        if (dfuDevPtr -> openConnection(2) != 0)
            return -1;
        sleep(1);
        dfuDevPtr -> freeDevice();
    }
     */
    return 0;
}

- (void)updateStatus:(NSString*)text color:(NSColor*)color1 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext = NULL;
        static bool firstline = true;
        
        if (firstline) {
            logtext = @"[+]  ";
            firstline = false;
        }
        else if (!firstline) {
            logtext = @"\n[+]  ";
        }

        logtext = [logtext stringByAppendingString:text];
        NSColor *color = color1;
        NSFont* font = [NSFont fontWithName:@"Helvetica Neue" size:13.37];
         
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color, NSFontAttributeName : font};
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logtext attributes:attrs];
        [[self->_statuslabel textStorage] appendAttributedString:attrStr];
        [self->_statuslabel scrollRangeToVisible:NSMakeRange([[self->_statuslabel string] length], 0)];
    });
}

- (int) patchFiles {
    
    NSTask *ibsspatch = [[NSTask alloc] init];
    NSTask *ibecpatch = [[NSTask alloc] init];
    ibsspatch.launchPath = @"/usr/bin/bspatch";
    ibsspatch.arguments = @[];
    ibecpatch.launchPath = @"/usr/bin/bspatch";
    ibecpatch.arguments = @[];
    
    NSString *board = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    NSString *LDResourcesPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/LDResources"];
    
    if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0) {
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.iphone6.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.iphone6.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibss5s.patch"]];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.iphone6.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.iphone6.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibec5s.patch"]];
    }
    
    else if (strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0) {
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibss_ipad4.patch"]];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibec_ipad4.patch"]];
    }
    
    else if (strcmp(boardcmp, "j85ap") == 0 || strcmp(boardcmp, "j86ap") == 0) {
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4b.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4b.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibss_ipad4b.patch"]];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4b.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4b.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"/Patches/ibec_ipad4b.patch"]];
    }
    [ibsspatch launch];
    [ibsspatch waitUntilExit];
    [ibecpatch launch];
    [ibecpatch waitUntilExit];
    
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

- (void)bootchainUploadManager:(NSString*)filename reconnect:(bool)reconnect {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:[NSString stringWithFormat:@"Sending %@", filename] color:[NSColor greenColor]];
    });
    
    if (dfuDevPtr -> sendFile(filename.UTF8String, reconnect) == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:[NSString stringWithFormat:@"Successfully booted %@", filename] color:[NSColor cyanColor]];
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showAlert:@"DFU device got lost" content:@"Please reconnect the USB cable to your Mac. LeetDown will automatically continue when it detects a device"];
    });
    int i = 0;
    while (dfuDevPtr -> openConnection(5) != 0) {
        printf("reconnect attempt %i\n", i);
        i++;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissAlert];
    });
    dfuDevPtr -> setAllDeviceInfo();
    [self bootchainUploadManager:filename reconnect:false];
    
}

- (int)sendBootchain {
    
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    NSString *board = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    
    if ([getPref(@"resetreq") isEqual:@"1"]) {
        [self bootchainUploadManager:@"/dev/null" reconnect:false];
        sleep(5);
    }

    if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0) {
        
        [self bootchainUploadManager:[tempipswdir stringByAppendingString:@"/Firmware/DFU/iBSS.iphone6.RELEASE.im4p"] reconnect:true];
        sleep(5);
        [self bootchainUploadManager:[tempipswdir stringByAppendingString:@"/Firmware/DFU/iBEC.iphone6.RELEASE.im4p"] reconnect:true];
    }
    else if (strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0) {
        
        [self bootchainUploadManager:[tempipswdir stringByAppendingString:@"/Firmware/DFU/iBSS.ipad4.RELEASE.im4p"] reconnect:true];
        sleep(5);
        [self bootchainUploadManager:[tempipswdir stringByAppendingString:@"/Firmware/DFU/iBEC.ipad4.RELEASE.im4p"] reconnect:true];
    }
    else if (strcmp(boardcmp, "j85ap") == 0 || strcmp(boardcmp, "j86ap") == 0) {
        
        [self bootchainUploadManager:[tempipswdir stringByAppendingString:@"/Firmware/DFU/iBSS.ipad4b.RELEASE.im4p"] reconnect:true];
        sleep(5);
        [self bootchainUploadManager:[tempipswdir stringByAppendingString:@"/Firmware/DFU/iBEC.ipad4b.RELEASE.im4p"] reconnect:true];
    }
    return 0;
}

- (void)infoLog:(NSString*)text color:(NSColor*)color1 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext = @"";
        logtext = [logtext stringByAppendingString:text];
        logtext = [logtext stringByReplacingOccurrencesOfString:@"{\n}" withString:@""];
        NSColor *color = color1;
        NSFont* font = [NSFont fontWithName:@"Helvetica Neue" size:13.37];
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color, NSFontAttributeName : font};
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logtext attributes:attrs];
        [[self->_statuslabel textStorage] appendAttributedString:attrStr];
        [self->_statuslabel scrollRangeToVisible:NSMakeRange([[self->_statuslabel string] length], 0)];
    });
}



- (int) PrintDevInfo  {

    [self infoLog: @"\n\n============= DEVICE INFO =============\n" color:[NSColor cyanColor]];
    [self infoLog: @"\nModel Name: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s", dfuDevPtr -> getDisplayName()] color:[NSColor greenColor]];
    [self infoLog: @"\nHardware Model: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()] color:[NSColor greenColor]];
    [self infoLog: @"\nECID: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%llu", dfuDevPtr -> getDevInfo() -> ecid] color:[NSColor greenColor]];
    [self infoLog: @"\nSerial Tag: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s", dfuDevPtr -> getDevInfo() -> srtg] color:[NSColor greenColor]];
    [self infoLog: @"\nAPNonce:" color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%@", NSNonce(dfuDevPtr -> getDevInfo() -> ap_nonce, dfuDevPtr -> getDevInfo() -> ap_nonce_size)] color:[NSColor greenColor]];
    [self infoLog:@"\nCPID: " color:[NSColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%@", NSCPID(&dfuDevPtr -> getDevInfo() -> cpid)] color:[NSColor greenColor]];
    [self infoLog: @"\nDestination Firmware: " color:[NSColor cyanColor]];
    [self infoLog: getPref(@"destinationFW") color:[NSColor greenColor]];
    [self infoLog:@"\nPwned: " color:[NSColor cyanColor]];
    if (dfuDevPtr -> checkPwn()) {
        [self infoLog: @"Yes" color:[NSColor greenColor]];
    }
    else {
        [self infoLog: @"No" color:[NSColor greenColor]];
    }
    [self infoLog: @"\n\n=====================================" color:[NSColor cyanColor]];
    return 0;
}

lockdownd_client_t lockdown = NULL;
idevice_t devptr = NULL;

- (int) discoverNormalDevices {
    
    static bool supported = false;
    
    if (openNormalModeConnection(devptr, 5) != 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Failed to connect, please reconnect to try again" color:[NSColor redColor]];
        });
        return -1;
    }
    
    NSString* devname = getDeviceName(devptr, lockdown);
    if ([devname isEqualToString:@"err_pair"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:[NSString stringWithFormat:@"Tap the \"trust\" button on your device and reconnect to continue"] color:[NSColor yellowColor]];
        });
        return -1;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:[NSString stringWithFormat:@"Successfully connected to %@", getDeviceName(devptr, lockdown)] color:[NSColor greenColor]];
    });
    char* ecid = queryKey(lockdown, "UniqueChipID");
    char* hwModel = queryKey(lockdown, "HardwareModel");
    
    if (ecid == NULL || hwModel == NULL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Failed to access device details, unable to start a restore session" color:[NSColor redColor]];
        });
        return -1;
    }
    
    NSString *destination;
    
    // check if the device is compatible.
    if (strcmp(hwModel, "N51AP") == 0 || strcmp(hwModel, "N53AP") == 0 || strcmp(hwModel, "J71AP") == 0 || strcmp(hwModel, "J72AP") == 0 || strcmp(hwModel, "J73AP") == 0 || strcmp(hwModel, "J85AP") == 0 || strcmp(hwModel, "J86AP") == 0) {
        
        destination = @"10.3.3";
        supported = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            _mainbox.fillColor = [NSColor colorWithSRGBRed:0.105882352941176f green:0.305882352941176f blue:0.317647058823529f alpha:1.0f];
        });
        
    }
    else if (strcmp(hwModel, "N41AP") == 0 || strcmp(hwModel, "N42AP") == 0 || strcmp(hwModel, "P101AP") == 0 || strcmp(hwModel, "P102AP") == 0 || strcmp(hwModel, "P103AP") == 0) {
        
        destination = @"8.4.1";
        supported = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            _mainbox.fillColor = [NSColor colorWithRed:44.0f/255.0f green:33.0f/255.0f blue:54.0f/255.0f alpha:1.0];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:[NSString stringWithFormat: @"%s is not supported", hwModel] color:[NSColor redColor]];
        });
        dfuDevPtr -> freeDevice();
        return -1;
    }
    
    modifyPref(@"destinationFW", destination);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self dfuhelpoutlet] setEnabled:false];
        [[self dfuhelpoutlet] setHidden:true];
        [[self versionLabel] setAlphaValue:1.0];
        
        [self updateStatus:[NSString stringWithFormat:@"Telling %s to enter recovery mode", hwModel] color:[NSColor whiteColor]];
    });
    lockdownd_enter_recovery(lockdown);
    
    [self discoverRestoreDevices:0];
    return 0;
}

- (int) discoverRestoreDevices:(int)mode {
    
    // mode = 0: rec
    // mode = 1: dfu
    static bool dfuPhase = false;

    if (discoverStateEnded) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Warning: Device reconnected" color:[NSColor yellowColor]];
        });
        return 0;
    }
    if (dfuDevPtr -> openConnection(50) != 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"An unknown error occured connecting to iOS device" color:[NSColor redColor]];
        });
        return -1;
    }
    if (strcmp(dfuDevPtr -> getDeviceMode(), "Unknown") == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Device is in an invalid state, please place it in DFU mode to proceed" color:[NSColor redColor]];
        });
        return -1;
    }
    
    ECID = [NSString stringWithFormat:@"%llu", dfuDevPtr -> getDevInfo() -> ecid];
    
    if (mode == 0 && (strcmp(dfuDevPtr -> getDeviceMode(), "Recovery") == 0)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Device successfully entered recovery mode" color:[NSColor greenColor]];
        });
        dfuPhase = true;
        
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
        NSViewController *dfuhelpervc = [storyboard instantiateControllerWithIdentifier:@"DFUHelper"];
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self.view.window.contentViewController presentViewControllerAsSheet:dfuhelpervc];
        });
     
        // sleep until the signal
        while (!LD_signalReceived) {
            [LD_conditionVariable wait];
        }
        [self discoverRestoreDevices:1];
        return 0;
        
    }
    
    if (mode == 1) {
        // now check if the device is in any other mode other than DFU.
        if (!(dfuDevPtr -> getDevInfo() -> srtg)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (strcmp(dfuDevPtr -> getDeviceMode(), "Unknown") == 0) {
                    [self updateStatus:@"Device is in an invalid state, please place it in DFU mode to proceed" color:[NSColor redColor]];
                }
                else {
                    [self updateStatus:[NSString stringWithFormat:@"%@ with ECID: %@ is connected in %@ mode instead of DFU mode, please place it in DFU mode to proceed", [NSString stringWithUTF8String:dfuDevPtr -> getDisplayName()], ECID, [NSString stringWithUTF8String:dfuDevPtr -> getDeviceMode()]] color:[NSColor redColor]];
                }
            });
            dfuDevPtr -> freeDevice();
            usleep(500000);
            return -1;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:[NSString stringWithFormat: @"%s is supported", dfuDevPtr -> getDisplayName()] color:[NSColor greenColor]];
            [self PrintDevInfo];
            self -> _selectIPSWoutlet.enabled = true;
            self -> _selectIPSWoutlet.title = [[@"Select " stringByAppendingString:getPref(@"destinationFW")] stringByAppendingString:@" iPSW"];
        });
        return 0;
    }

    return -1;
}

- (int) restore32 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"Restoring device" color:[NSColor greenColor]];
    });
    
    NSString *board = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    
    NSTask *restore = [[NSTask alloc]init];
    restore.launchPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/futurerestore"];
    restore.arguments = @[];
    NSString *bb = @"--latest-baseband"; // use this for now, baseband downgrade option will be added later.
    NSString *ticket = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    NSString *ipswPath=dict[@"32iPSWLoc"];
    
    if (strcmp(boardcmp, "n41ap") == 0 || strcmp(boardcmp, "n42ap") == 0 || strcmp(boardcmp, "p102ap") == 0 || strcmp(boardcmp, "p103ap") == 0) {

        bool downgradeBB = [getPref(@"downgradeBB") boolValue];
        if (downgradeBB) {
            bb = @"--latest-baseband";
            restore.arguments = @[@"-t", ticket, bb, @"--use-pwndfu", ipswPath];
        }
        else {
            NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
            NSString *bbDestination = [tempipswdir stringByAppendingString:@"/Mav5-8.02.00.Release.bbfw"];
            [[NSFileManager defaultManager] createDirectoryAtPath:tempipswdir withIntermediateDirectories:NO attributes:NULL error:NULL];
            NSString *baseband = @"Firmware/Mav5-8.02.00.Release.bbfw";
            [SSZipArchive unzipEntityName:baseband fromFilePath:ipswPath toDestination:bbDestination];
            bb = bbDestination;
            
            NSString *devmodel = [NSString stringWithFormat:@"%s", dfuDevPtr -> getProductType()];
            NSString *bm =[[[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/BuildManifests/"] stringByAppendingString:[NSString stringWithFormat:@"%@", devmodel]] stringByAppendingString:@".plist"];
            restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"--use-pwndfu", ipswPath];
        }
    }
    else {
        bb = @"--no-baseband";
        restore.arguments = @[@"-t", ticket, bb, @"--use-pwndfu", ipswPath];
    }
    
    
    NSPipe *stdoutPipe = [NSPipe pipe];
    [restore setStandardOutput:stdoutPipe];

    NSFileHandle *stdoutHandle = [stdoutPipe fileHandleForReading];
    [stdoutHandle waitForDataInBackgroundAndNotify];
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification
                                                                    object:stdoutHandle queue:nil
                                                                usingBlock:^(NSNotification *note)
    {
        NSData *dataRead = [stdoutHandle availableData];
        NSString *stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self infoLog:stringRead color:[NSColor whiteColor]];
        });
        [stdoutHandle waitForDataInBackgroundAndNotify];
    }];
    
    [restore launch];
    [restore waitUntilExit];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    return [restore terminationStatus];
}

- (int) restore64 {

    if ([self patchFiles] != 0) {
        [self updateStatus:@"Error patching bootchain" color:[NSColor redColor]];
        return -1;
    }
   
    if ([self sendBootchain] != 0) {
        [self updateStatus:@"Error sending bootchain" color:[NSColor redColor]];
        return -1;
    }
    sleep(1);
            
    NSString *devmodel = [NSString stringWithFormat:@"%s", dfuDevPtr -> getProductType()];
    NSString *board = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    
    NSTask *restore = [[NSTask alloc]init];
    restore.launchPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/futurerestore64"];
    restore.arguments = @[];
    NSString *BootLogo = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Bootlogos/logo_64.img4"];
    const char *LDBootlogo = [BootLogo cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *bm =[[[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/BuildManifests/"] stringByAppendingString:[NSString stringWithFormat:@"%@", devmodel]] stringByAppendingString:@".plist"];
    NSString *bb = [tempipswdir stringByAppendingString:@"/Firmware/Mav7Mav8-7.60.00.Release.bbfw"];
    NSString *sep = [[tempipswdir stringByAppendingString:@"/Firmware/all_flash/sep-firmware."] stringByAppendingString: [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()]];
    sep = [sep substringToIndex:[sep length] -2];
    sep = [sep stringByAppendingString:@".RELEASE.im4p"];
    NSString *ticket = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
    [self updateStatus:@"Sending bootlogo" color:[NSColor greenColor]];
    dfuDevPtr -> sendFile(LDBootlogo, true);
    dfuDevPtr -> sendCommand("setpicture 0x1", false);
    
    if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0) {
        restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"-m", bm, @"-s", sep, tempipswdir];
    }

    else if (strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j85ap") == 0) {
        restore.arguments = @[@"-t", ticket, @"-p", bm, @"-m", bm, @"-s", sep, tempipswdir, @"-d", @"--no-baseband"];
    }
    else if (strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0 || strcmp(boardcmp, "j86ap") == 0 || strcmp(boardcmp, "j87ap") == 0) {
        restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"-m", bm, @"-s", sep, @"-d", tempipswdir];
    }
    sleep(1);
    dfuDevPtr -> freeDevice();
    sleep(3);
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self updateStatus:@"Restore process started" color:[NSColor greenColor]];
    });
    [restore launch];
    [restore waitUntilExit];
    return [restore terminationStatus];
}

- (IBAction)selectIPSW:(id)sender {
    
    cleanUp();
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    __block NSString *ipswLocation = @"";
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Select iPSW"];
    [alert setInformativeText:@"Would you like to browse for an iPSW or let LeetDown download the correct one for your device? A copy of the iPSW will be saved to your Documents folder"];
    [alert addButtonWithTitle:@"Download an iPSW"];
    [alert addButtonWithTitle:@"Browse for an iPSW"];
    [alert setAlertStyle:NSAlertStyleWarning];

    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        
    if (returnCode == NSAlertFirstButtonReturn) {
            
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            const char *devmodel = dfuDevPtr -> getProductType();

            NSString *ipswname = [[[[NSString stringWithFormat:@"%s", devmodel] stringByAppendingString: @"_"] stringByAppendingString:getPref(@"destinationFW")] stringByAppendingString:@"_stock.ipsw"];
            ipswLocation = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingString:@"/"] stringByAppendingString:ipswname];
            if ([[NSFileManager defaultManager] fileExistsAtPath:ipswLocation]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateStatus:[NSString stringWithFormat: @"You already have an iPSW in your Documents folder named \"%@\". Either delete the iPSW or specify it by clicking \"Browse for an iPSW\" button.", ipswname] color:[NSColor redColor]];
                });
            return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{

                _selectIPSWoutlet.enabled = false;
                _dfuhelpoutlet.alphaValue = 0;
                _percentage.stringValue = @"%0";
                [self infoLog:@"\n" color:[NSColor whiteColor]];
                [self updateStatus:[NSString stringWithFormat:@"Downloading iOS %@ iPSW for %s...", getPref(@"destinationFW"), devmodel] color:[NSColor greenColor]];
                [_uselessIndicator setIndeterminate:NO];
                [_uselessIndicator setMaxValue:1];
            });
                    
            if (strcmp(devmodel, "iPhone6,1" ) == 0 || strcmp(devmodel, "iPhone6,2" ) == 0) {
                [self downloadiPSW:@"http://appldnld.apple.com/ios10.3.3/091-23133-20170719-CA8E78E6-6977-11E7-968B-2B9100BA0AE3/iPhone_4.0_64bit_10.3.3_14G60_Restore.ipsw" name:ipswname];
            }
            else if (strcmp(devmodel, "iPad4,1" ) == 0 || strcmp(devmodel, "iPad4,2" ) == 0 || strcmp(devmodel, "iPad4,3" ) == 0 || strcmp(devmodel, "iPad4,4" ) == 0 || strcmp(devmodel, "iPad4,5" ) == 0) {
                [self downloadiPSW:@"http://appldnld.apple.com/ios10.3.3/091-23378-20170719-CA983C78-6977-11E7-8922-3D9100BA0AE3/iPad_64bit_10.3.3_14G60_Restore.ipsw" name:ipswname];
            }
            else if (strcmp(devmodel, "iPhone5,1") == 0) {
                [self downloadiPSW:@"http://appldnld.apple.com/ios8.4.1/031-31186-20150812-751D243C-3C8F-11E5-8E4F-B51A3A53DB92/iPhone5,1_8.4.1_12H321_Restore.ipsw" name:ipswname];
            }
            else if (strcmp(devmodel, "iPhone5,2") == 0) {
                [self downloadiPSW:@"http://appldnld.apple.com/ios8.4.1/031-31065-20150812-7518F132-3C8F-11E5-A96A-A11A3A53DB92/iPhone5,2_8.4.1_12H321_Restore.ipsw" name:ipswname];
            }
            else if (strcmp(devmodel, "iPad3,4") == 0) {
                [self downloadiPSW:@"http://appldnld.apple.com/ios8.4.1/031-31234-20150812-751D30B2-3C8F-11E5-895A-BD1A3A53DB92/iPad3,4_8.4.1_12H321_Restore.ipsw" name:ipswname];
            }
            else if (strcmp(devmodel, "iPad3,5") == 0) {
                [self downloadiPSW:@"http://appldnld.apple.com/ios8.4.1/031-31092-20150812-7518CFB8-3C8F-11E5-B849-A51A3A53DB92/iPad3,5_8.4.1_12H321_Restore.ipsw" name:ipswname];
            }
            else if (strcmp(devmodel, "iPad3,6") == 0) {
                [self downloadiPSW:@"http://appldnld.apple.com/ios8.4.1/031-31187-20150812-751A8A7E-3C8F-11E5-B300-B71A3A53DB92/iPad3,6_8.4.1_12H321_Restore.ipsw" name:ipswname];
            }
            [self extractIPSW:[NSURL URLWithString:ipswLocation]];
        });
    }
    else {
        NSString *filepath = @"";
        NSOpenPanel* openDlg = [NSOpenPanel openPanel];
        NSArray* fileTypes = [NSArray arrayWithObjects:@"ipsw", @"IPSW", nil];
        [openDlg setCanChooseFiles:YES];
        [openDlg setCanChooseDirectories:YES];
        [openDlg setAllowedFileTypes:fileTypes];

        if ([openDlg runModal] == NSModalResponseOK) {
            
            for (NSURL* URL in [openDlg URLs]) {
                
                filepath = URL.absoluteString;
                
                if (URL == NULL) {
                    [self updateStatus:@"Provided path is invalid" color:[NSColor redColor]];
                    return;
                }
                
                [[NSFileManager defaultManager] createDirectoryAtPath:tempipswdir withIntermediateDirectories:NO attributes:NULL error:NULL];
                [self extractIPSW:URL];
            }
        }
                self -> _downgradeButtonOut.enabled = false;
                self -> _selectIPSWoutlet.enabled = false;
                [self updateStatus:@"Verifying iPSW" color:[NSColor greenColor]];
                _uselessIndicator.indeterminate = true;
                    
                const char* selected_ipsw_version = [self ipswVersion:filepath];
        //const char* selected_ipsw_version = "";
                const char* required_ipsw_version = getPref(@"destinationFW").UTF8String;
                if (selected_ipsw_version == NULL) {
                    [self updateStatus:@"Selected iPSW is corrupt" color:[NSColor redColor]];
                    self -> _selectIPSWoutlet.enabled = true;
                    return;
                }
                if (strcmp(selected_ipsw_version, required_ipsw_version) != 0) {
                    [self updateStatus:[NSString stringWithFormat: @"This device only supports iOS %s downgrade, but the selected iPSW is for iOS %s", required_ipsw_version, selected_ipsw_version] color:[NSColor redColor]];
                    self -> _downgradeButtonOut.enabled = false;
                    self -> _selectIPSWoutlet.enabled = true;
                    return;
                }
                
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    
                    if ([getPref(@"skipCheck") isEqual:@"0"]) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self updateStatus:@"Checking iPSW size..." color:[NSColor cyanColor]];
                        });
                        //if ([self iPSWcheck:URL] != 0) {
                            return;
                        //}
                    }
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        [self updateStatus:@"Successfully verified the iPSW" color:[NSColor cyanColor]];
                            
                    });
                    // if it's an A6 device, set plist but do not extract anything
                    if (strcmp(getPref(@"destinationFW").UTF8String, "8.4.1") == 0) {
                        NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
                        NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
                        //[dict setValue:filepath forKey:@"32iPSWLoc"];
                        [dict writeToFile:preferencePlist atomically:YES];
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            self -> _downgradeButtonOut.enabled = true;
                            self -> _selectIPSWoutlet.enabled = true;
                        });
                        return;
                    }
                    // if it's an A7 device or an A6 device with "downgrade baseband" option selected, extract the iPSW
                    dispatch_async(dispatch_get_main_queue(), ^(){
                            
                    });
                });
            }
    }];
}

- (void) backupBlob {
        
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
            NSURL *origBlobLoc = [NSURL fileURLWithPath:bloblocation];
            [[NSFileManager defaultManager] copyItemAtURL:origBlobLoc toURL:saveLocation error:nil];
            [self updateStatus:[NSString stringWithFormat:@"Saved blob to %@. Keep it safe!", saveLocation] color:[NSColor cyanColor]];
        }
    }];
}

- (IBAction)downgradeButtonAct:(id)sender {
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Warning"];
    [alert setInformativeText:@"Downgrading your device will erase all the data on it"];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        
        if (returnCode == NSAlertSecondButtonReturn) {
            [self updateStatus:@"Restore was cancelled by user" color:[NSColor yellowColor]];
            return;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            restoreStarted = true;
            dispatch_async(dispatch_get_main_queue(), ^(){
                [self -> _uselessIndicator setUsesThreadedAnimation:NO];
                [self -> _uselessIndicator setHidden:NO];
                [self -> _uselessIndicator setIndeterminate:YES];
                [self -> _uselessIndicator startAnimation:nil];
                _dfuhelpoutlet.enabled = false;
                _dfuhelpoutlet.alphaValue = 0;
                _selectIPSWoutlet.enabled = false;
                _downgradeButtonOut.enabled = false;
                _versionLabel.alphaValue = 1;
            });

            if (pwned && strcmp(getPref(@"destinationFW").UTF8String, "10.3.3") == 0) {
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self updateStatus:@"Device was already pwned, skipping exploitation" color:[NSColor cyanColor]];
                });
            }
            
            else {
                dfuDevPtr -> freeDevice(); // need to free the device so that iPwnder32 can take over
                [USB_VC stopMonitoringUSBDevices];
                dfuDevPtr -> pwnDevice();
                if (dfuDevPtr -> checkPwn() != 0) {
                    return;
                }
                if (dfuDevPtr -> getClient() == NULL) {
                    dfuDevPtr -> openConnection(5); // now reconnect to device
                    dfuDevPtr -> setAllDeviceInfo(); // set the rest
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(){
                [self updateStatus:@"Fetching OTA blob" color:[NSColor greenColor]];
            });
            
            if ([self saveOTABlob] == -2) {
                dispatch_async(dispatch_get_main_queue(), ^(){
                    
                    [self updateStatus:[NSString stringWithFormat: @"Failed to save %@ OTA blob. Is it being signed?", getPref(@"destinationFW")]  color: [NSColor redColor]];
                    return;
                });
            }
            
            dispatch_async(dispatch_get_main_queue(), ^(){
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Backup your blob"];
                [alert setInformativeText:@"Would you like to backup your SHSH blob? By backing up your blob, you will be able to downgrade to OTA firmwares with LeetDown even if Apple decides to unsign them someday."];
                [alert addButtonWithTitle:@"Yes"];
                [alert addButtonWithTitle:@"Skip"];
                [alert setAlertStyle:NSAlertStyleWarning];
                [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSAlertFirstButtonReturn) {
                        [self backupBlobWithCompletion:^{
                            [self restoreWrapper];
                        }];
                    } else {
                        [self restoreWrapper];
                    }
                }];
            });
        });
    }];
}

- (void)backupBlobWithCompletion:(void (^)(void))completion {
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
            [self updateStatus:[NSString stringWithFormat:@"Saved blob to %@. Keep it safe!", saveLocation] color:[NSColor cyanColor]];
        }
        completion();
    }];
}

- (void)restoreWrapper {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        if (strcmp(getPref(@"destinationFW").UTF8String, "10.3.3") == 0) {
            [self restore64];
            dispatch_async(dispatch_get_main_queue(), ^(){
                [self -> _uselessIndicator stopAnimation:nil];
                _selectIPSWoutlet.enabled = true;
            });
            return;
        }
        dfuDevPtr -> freeDevice();
        [self restore32];
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self -> _uselessIndicator stopAnimation:nil];
            _selectIPSWoutlet.enabled = true;
        });
    });
}

- (void)redirectLogToDocuments {
     NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
     NSString *documentsDirectory = [allPaths objectAtIndex:0];
     NSString *pathForLog = [documentsDirectory stringByAppendingPathComponent:@".txt"];
     freopen([pathForLog cStringUsingEncoding:NSASCIIStringEncoding],"a+",stdout);
}

- (void)showAlert:(NSString*)title content:(NSString*)content {
    
    self.alert = [[NSAlert alloc] init];
    [self.alert setMessageText:title];
    [self.alert setInformativeText:content];
    [self.alert addButtonWithTitle:@"OK"];
    NSButton *button = [[self.alert buttons] objectAtIndex:0];
    [button setHidden:YES];
    [self.alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {

        }];
}

- (void)dismissAlert {
    [self.view.window endSheet:self.alert.window];
}

- (int)checkActivation {
    [self updateStatus:@"Querying the device for activation" color:[NSColor whiteColor]];
    
    plist_t state = NULL;
    lockdownd_get_value(lockdown, NULL, "ActivationState", &state);
    
    if (!state) {
        [self updateStatus:@"Unable to determine the activation state of the device" color:[NSColor redColor]];
        return -1;
    }
    
    char *state_str = NULL;
    plist_get_string_val(state, &state_str);
    
    if (state_str && strcmp(state_str, "Unactivated") == 0) {
        [self updateStatus:@"Please active the connected device and reconnect to continue" color:[NSColor redColor]];
        return -1;
    }
    [self updateStatus:@"Device is activated, continuing" color:[NSColor greenColor]];
    return 0;
}

- (void) checkLDUpdates:(bool)nightly {
    
    NSString *urlString = @"";
    if (nightly) {
        urlString = @"https://api.github.com/repos/rA9stuff/LeetDown/actions/artifacts";
    }
    else {
        urlString = @"https://api.github.com/repos/rA9stuff/LeetDown/releases/latest";
    }
    [UpdateController sendGETRequestWithURL:urlString completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"LeetDown could not check for updates: %@", error.localizedDescription);
        } 
        else {
            if (nightly) {
                NSString* hash = [response[@"artifacts"][0][@"workflow_run"][@"head_sha"] substringToIndex:7];
                NSLog(@"Latest nightly LeetDown hash: %@", hash);
            }
            else {
                NSLog(@"Latest notarized LeetDown version: %@", response[@"tag_name"]);
            }
            
            // check if current version number is less than the latest version number
            if ((!nightly && [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] compare:response[@"tag_name"] options:NSNumericSearch] == NSOrderedAscending) || (nightly && [response[@"artifacts"][0][@"workflow_run"][@"head_sha"] substringToIndex:7] != getPref(@"nightlyHash"))) {
                
                dispatch_async(dispatch_get_main_queue(), ^(){
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert setMessageText:@"Update available"];
                    [alert setInformativeText:[NSString stringWithFormat: @"A new version of LeetDown (%@) is available. Would you like to download it?", nightly ? [response[@"artifacts"][0][@"workflow_run"][@"head_sha"] substringToIndex:7] : response[@"tag_name"]]];
                    [alert addButtonWithTitle:@"Update"];
                    [alert addButtonWithTitle:@"Cancel"];
                    [alert setAlertStyle:NSAlertStyleWarning];
                    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
                        if (returnCode == NSAlertFirstButtonReturn) {
                            [self createUpdateView];
                        }
                    }];
                });
            }
        }
    }];
}

- (void) createUpdateView {
    
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    NSViewController *updateVC = [storyboard instantiateControllerWithIdentifier:@"UpdateController"];
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self.view.window.contentViewController presentViewControllerAsSheet:updateVC];
    });
}



- (void)viewDidLoad {
    [super viewDidLoad];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self checkLDUpdates:([getPref(@"nightlyHash") isEqual: @""] ? false : true)];
    });

    LD_conditionVariable = [[NSCondition alloc] init];
    LD_signalReceived = NO;
    
    NSString *res = getPref(@"DebugEnabled");
    
    if ([res isEqualToString:@"1"])
        [self startMonitoringStdout];
    
    // search for USB devices
    [USB_VC startMonitoringUSBDevices:self];
    
    // check if this is a nightly build
    res = getPref(@"nightlyHash");
    if (strcmp(res.UTF8String, "") != 0)
        _versionLabel.stringValue = [@"Nightly " stringByAppendingString:res];

    cleanUp();
    
    _versionLabel.enabled = true;
    _versionLabel.alphaValue = 1.0;
    [_uselessIndicator setHidden:NO];
    [_uselessIndicator setIndeterminate:YES];
    [_uselessIndicator setUsesThreadedAnimation:YES];
    [self updateStatus:@"Waiting for a device in Normal Mode" color:[NSColor whiteColor]];

}

@end
