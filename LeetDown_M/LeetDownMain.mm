
  
#import "LeetDownMain.h"
#include "DFUDevice.h"
#include "plistModifier.h"
#define USB_TIMEOUT 10000

uint64_t ecid = 0;
bool connected = false;

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
    /*
        well, macOS should technincally clean the tmp path automatically but
        I don't want to risk leaving junk behind so
     */
     
    if ([fileManager fileExistsAtPath:tempipswdir]) {
        [fileManager removeItemAtPath:tempipswdir error:NULL];
    }
    
}

@implementation ViewController

bool firstline = true;
bool pwned = false;

irecv_client_t client = NULL;
irecv_device_t device = NULL;
DFUDevice *dfuDevPtr = new DFUDevice; // initialize it with defualt constructor first, since we only need ECID not to be NULL to connect to device

- (NSString*)MD5:(NSData*)input
{
  // Create byte array of unsigned chars
  unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];

  // Create 16 byte MD5 hash value, store in buffer
  CC_MD5(input.bytes, input.length, md5Buffer);

  // Convert unsigned char buffer to NSString of hex values
  NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
  for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
    [output appendFormat:@"%02x",md5Buffer[i]];
    NSString *md5val = [NSString stringWithFormat:@"%@", output];
  return md5val;
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
    NSString *md5CheckValue;
    //NSString* cpid = @"8960";
    NSString* cpid = NSCPID(&dfuDevPtr -> getDevInfo() -> cpid);
    if (strcmp(cpid.UTF8String, "8960") != 0 && strcmp(cpid.UTF8String, "8965") != 0) {
        md5CheckValue = [[NSString stringWithFormat:@"%s", dfuDevPtr -> getProductType()] stringByAppendingString:@"MD5"];
    }
    else if (strcmp(dfuDevPtr -> getProductType(), "iPhone6,1") == 0 || strcmp(dfuDevPtr -> getProductType(), "iPhone6,2") == 0) {
        md5CheckValue = @"iPhone64MD5";
    }
    else {
        md5CheckValue = @"iPad64MD5";
    }
    NSData *ipswData = [NSData dataWithContentsOfURL:ipswLocation];
    plistModifier correctMD5;
    if (strcmp([self MD5:ipswData].UTF8String, correctMD5.getPref(md5CheckValue).UTF8String) != 0) {
        
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self updateStatus:@"iPSW is corrupt! If you think this is a mistake, disable MD5 check in settings" color:[NSColor redColor]];
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
        }
                                              
        completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_uselessIndicator setUsesThreadedAnimation:NO];
            [_uselessIndicator setIndeterminate:YES];
            [_uselessIndicator startAnimation:nil];
            [self updateStatus:@"Successfully downloaded iPSW" color:[NSColor cyanColor]];
            [_percentage setStringValue:@""];
            [_versionLabel setAlphaValue:1];
            
            plistModifier md5check;
            
            if ([md5check.getPref(@"skipMD5")  isEqual: @"0"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateStatus:@"Checking md5 of the iPSW..." color:[NSColor cyanColor]];
                });
                [self iPSWcheck:filePath];
                
            }
            NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
            NSString *zipEntityToExtract = @"BuildManifest.plist";
            NSString *destinationFilePath = [tempipswdir stringByAppendingString:@"/BuildManifest.plist"];
            NSString *zipPath = urlns;
            [SSZipArchive unzipEntityName:zipEntityToExtract fromFilePath:zipPath toDestination:destinationFilePath];
          
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                                
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
                        
                        plistModifier locationObject;
                        locationObject.modifyPref(@"32iPSWLoc", tempipswdir);
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


- (int)exploitDevice {
    
    sleep(1);
    NSTask *exploit = [[NSTask alloc] init];
    [exploit setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/ipwnder_macosx"]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"Exploiting device..." color:[NSColor greenColor]];
    });

    [exploit setArguments:@[@"-p"]];
    [exploit setCurrentDirectoryPath:@"/Applications/LeetDown.app/Contents/Resources/LDResources"];
    [exploit launch];
    [exploit waitUntilExit];

    sleep(1);
    if (!dfuDevPtr -> checkPwn()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Exploit failed, please re-enter DFU mode to try again" color:[NSColor redColor]];
            [_uselessIndicator stopAnimation:nil];
            _downgradeButtonOut.enabled = true;
            _versionLabel.alphaValue = 0;
            _versionLabel.enabled = false;
            _dfuhelpoutlet.alphaValue = 1;
            _dfuhelpoutlet.enabled = true;
        });
        return -1;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"Exploit succeeded!" color:[NSColor cyanColor]];
    });
    
    // we want to minimize the # of times we connect to devices for stability reasons
    // so, get the info from the plist instead.
    plistModifier version;
    
    if (strcmp(version.getPref(@"destinationFW").UTF8String, "8.4.1") == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateStatus:@"Uploading pwned iBoot..." color:[NSColor cyanColor]];
        });
        NSTask *iBootUpload = [[NSTask alloc] init];
        [iBootUpload setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/ipwnder_macosx"]];
        [iBootUpload setArguments:@[@"--upload-iboot"]];
        [iBootUpload setCurrentDirectoryPath:@"/Applications/LeetDown.app/Contents/Resources/LDResources"];
        [iBootUpload launch];
        [iBootUpload waitUntilExit];
        sleep(1);
        if (dfuDevPtr -> openConnection(2) != 0)
            return -1;
        sleep(1);
        dfuDevPtr -> freeDevice();
    }
    return 0;
}

- (void)updateStatus:(NSString*)text color:(NSColor*)color1 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext = NULL;

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
    
    printf("inside patchFiles(), printing dev info\n");
    printf("printing dev info line 372\n");
    printf("SERIAL TAG -> %s\n", dfuDevPtr -> getDevInfo() ->srtg);
    printf("HARDWARE MODEL -> %s\n", dfuDevPtr -> getHardwareModel());

    
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
            [self updateStatus:@"5 second cooldown, re-plug now if needed on Apple Silicon" color:[NSColor whiteColor]];
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatus:@"Device was lost, reconnect the USB cable to your mac to resume the upload process" color:[NSColor yellowColor]];
    });
    int i = 0;
    while (dfuDevPtr -> openConnection(5) != 0) {
        printf("reconnect attempt %i\n", i);
        i++;
    }
    dfuDevPtr -> setAllDeviceInfo();
    [self bootchainUploadManager:filename reconnect:false];
    
}

- (int)sendBootchain {
    
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    NSString *board = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    plistModifier resetToggle;
    
    if ([resetToggle.getPref(@"resetreq") isEqual:@"1"]) {
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

int supported = 0;

- (int) PrintDevInfo  {

    plistModifier destinationObject;
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
    [self infoLog: destinationObject.getPref(@"destinationFW") color:[NSColor greenColor]];
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


bool firstrun = true;
bool newdevice = true;
unsigned long long devCompStr;
NSString *newECID = NULL;
NSString *oldECID = NULL;

- (int) comeDiscover {
    
    /*
     LeetDown should check for two conditions here:
     
     1: If the device is supported by 10.3.3 OTA downgrade
     2: If the device is connected in anything other than DFU mode
     */

    if (!dfuDevPtr -> deviceConnected()) {
        firstrun = true;
        return -1;
    }
        
    dfuDevPtr = new DFUDevice(client, device); // we can now initalize the ptr with the custom constructor and place all the info to this DFUDevice struct.
    if (oldECID == NULL) {
            
        oldECID = [NSString stringWithFormat:@"%llu", dfuDevPtr -> getDevInfo() -> ecid];
        newECID = [NSString stringWithFormat:@"%llu", dfuDevPtr -> getDevInfo() -> ecid];
        NSLog(@"%@", oldECID);
        firstrun = true;
    }
    newECID = [NSString stringWithFormat:@"%llu", dfuDevPtr -> getDevInfo() -> ecid];
    
    // check if we're looking at a different device or we're running this block for the first time.
    if (strcmp(oldECID.UTF8String, newECID.UTF8String) == 0 && !firstrun) {
        usleep(500000);
        dfuDevPtr -> freeDevice();
        return -1;
    }
                
    firstrun = false;
    oldECID = newECID;
        
    // now check if the device is in any other mode other than DFU.
    if (!(dfuDevPtr -> getDevInfo() -> srtg)) {
        [self updateStatus:[NSString stringWithFormat:@"%@ with ECID: %@ is connected in wrong mode, please place it in DFU mode to proceed", [NSString stringWithUTF8String:dfuDevPtr -> getDisplayName()], newECID] color:[NSColor redColor]];
        dfuDevPtr -> freeDevice();
        usleep(500000);
        return -1;
    }
    
    plistModifier plistObject; // create a plistModifier object to modify the "destinationFW" value.
    
        // check if the device is compatible.
    NSString *boardConfig = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    if (strcmp(boardConfig.UTF8String, "n51ap") == 0 || strcmp(boardConfig.UTF8String, "n53ap") == 0 || strcmp(boardConfig.UTF8String, "j71ap") == 0 || strcmp(boardConfig.UTF8String, "j72ap") == 0 || strcmp(boardConfig.UTF8String, "j73ap") == 0 || strcmp(boardConfig.UTF8String, "j85ap") == 0 || strcmp(boardConfig.UTF8String, "j86ap") == 0) {
        
        plistObject.modifyPref(@"destinationFW", @"10.3.3");
        supported = true;
        [self updateStatus:[NSString stringWithFormat: @"%s is supported", dfuDevPtr -> getDisplayName()] color:[NSColor greenColor]];
        [self PrintDevInfo];
        dfuDevPtr -> openConnection(5);
        dfuDevPtr -> setAllDeviceInfo();
        dispatch_async(dispatch_get_main_queue(), ^{
            self -> _selectIPSWoutlet.enabled = true;
            self -> _selectIPSWoutlet.title = [NSString stringWithFormat:@"Select 10.3.3 iPSW"];
            _mainbox.fillColor = [NSColor colorWithSRGBRed:0.105882352941176f green:0.305882352941176f blue:0.317647058823529f alpha:1.0f];
        });
    }
    else if (strcmp(boardConfig.UTF8String, "n41ap") == 0 || strcmp(boardConfig.UTF8String, "n42ap") == 0 || strcmp(boardConfig.UTF8String, "p101ap") == 0 || strcmp(boardConfig.UTF8String, "p102ap") == 0 || strcmp(boardConfig.UTF8String, "p103ap") == 0) {
        
        plistObject.modifyPref(@"destinationFW", @"8.4.1");
        supported = true;
        [self updateStatus:[NSString stringWithFormat: @"%s is supported", dfuDevPtr -> getDisplayName()] color:[NSColor greenColor]];
        [self PrintDevInfo];
        dispatch_async(dispatch_get_main_queue(), ^{
            self -> _selectIPSWoutlet.enabled = true;
            self -> _selectIPSWoutlet.title = [NSString stringWithFormat:@"Select 8.4.1 iPSW"];
            _mainbox.fillColor = [NSColor colorWithRed:44.0f/255.0f green:33.0f/255.0f blue:54.0f/255.0f alpha:1.0];
        });
    }
    else {
        [self updateStatus:[NSString stringWithFormat: @"%s is not supported", dfuDevPtr -> getDisplayName()] color:[NSColor redColor]];
        dfuDevPtr -> freeDevice();
    }

    return 0;
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
    NSString *stringValue=dict[@"32iPSWLoc"];
    
    if (strcmp(boardcmp, "n41ap") == 0 || strcmp(boardcmp, "n42ap") == 0 || strcmp(boardcmp, "p102ap") == 0 || strcmp(boardcmp, "p103ap") == 0) {
        bb = @"--latest-baseband";
    }
    else {
        bb = @"--no-baseband";
    }
    restore.arguments = @[@"-t", ticket, bb, @"--use-pwndfu", stringValue];
    [restore launch];
    [restore waitUntilExit];
    
    return [restore terminationStatus];
}

- (int) restore64 {
    
    printf("inside restore64(), printing dev info\n");
    printf("printing dev info line 657\n");
    printf("SERIAL TAG -> %s\n", dfuDevPtr -> getDevInfo() -> srtg);
    printf("HARDWARE MODEL -> %s\n", dfuDevPtr -> getHardwareModel());

    if ([self patchFiles] != 0) {
        [self updateStatus:@"Error patching bootchain" color:[NSColor redColor]];
        return -1;
    }
   
    if ([self sendBootchain] != 0) {
        [self updateStatus:@"Error sending bootchain" color:[NSColor redColor]];
        printf("line 669\n");
        return -1;
    }
    printf("line 672\n");
    sleep(1);
            
    NSString *devmodel = [NSString stringWithFormat:@"%s", dfuDevPtr -> getProductType()];
    NSString *board = [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()];
    const char *boardcmp = [board cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    
    NSTask *restore = [[NSTask alloc]init];
    restore.launchPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/futurerestore64"];
    restore.arguments = @[];
    NSString *BootLogo = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Bootlogos/bootlogo.img4"];
    const char *LDBootlogo = [BootLogo cStringUsingEncoding:NSASCIIStringEncoding];
    NSString *bm =[[[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/BuildManifests/"] stringByAppendingString:[NSString stringWithFormat:@"%@", devmodel]] stringByAppendingString:@".plist"];
    NSString *bb = [tempipswdir stringByAppendingString:@"/Firmware/Mav7Mav8-7.60.00.Release.bbfw"];
    NSString *sep = [[tempipswdir stringByAppendingString:@"/Firmware/all_flash/sep-firmware."] stringByAppendingString: [NSString stringWithFormat:@"%s", dfuDevPtr -> getHardwareModel()]];
    sep = [sep substringToIndex:[sep length] -2];
    sep = [sep stringByAppendingString:@".RELEASE.im4p"];
    NSString *ticket = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/SHSH/blob.shsh"];
    
    dfuDevPtr -> sendFile(LDBootlogo, true);
    dfuDevPtr -> sendCommand("setpicture 0", false);
    
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
    dfuDevPtr -> sendCommand("bgcolor 254 254 254", false);
    dfuDevPtr -> freeDevice();
    sleep(3);
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self updateStatus:@"Starting restore process" color:[NSColor greenColor]];
    });
    [restore launch];
    [restore waitUntilExit];
    return [restore terminationStatus];
}

- (IBAction)selectIPSW:(id)sender {
    
    cleanUp();
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
            const char *devmodel = dfuDevPtr -> getProductType();
            plistModifier version;
            NSString *ipswname = [[[[NSString stringWithFormat:@"%s", devmodel] stringByAppendingString: @"_"] stringByAppendingString:version.getPref(@"destinationFW")] stringByAppendingString:@"_stock.ipsw"];
            NSString *ipswLocation = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingString:@"/"] stringByAppendingString:ipswname];
            if ([[NSFileManager defaultManager] fileExistsAtPath:ipswLocation]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateStatus:[NSString stringWithFormat: @"You already have an iPSW in your Documents folder named \"%@\". Either delete that iPSW or specify it by clicking \"Browse for an iPSW\".", ipswname] color:[NSColor redColor]];
                });
            return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                plistModifier destinationObject;
                _selectIPSWoutlet.enabled = false;
                _dfuhelpoutlet.alphaValue = 0;
                _percentage.stringValue = @"%0";
                [self infoLog:@"\n" color:[NSColor whiteColor]];
                [self updateStatus:[NSString stringWithFormat:@"Downloading iOS %@ iPSW for %s...", destinationObject.getPref(@"destinationFW"), devmodel] color:[NSColor greenColor]];
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
        });
    }
    else {
            
        NSOpenPanel* openDlg = [NSOpenPanel openPanel];
        NSArray* fileTypes = [NSArray arrayWithObjects:@"ipsw", @"IPSW", nil];
        [openDlg setCanChooseFiles:YES];
        [openDlg setCanChooseDirectories:YES];
        [openDlg setAllowedFileTypes:fileTypes];

        if ([openDlg runModal] == NSModalResponseOK) {
                
            for (NSURL* URL in [openDlg URLs]) {

                NSString *filepath = URL.absoluteString;
                filepath = [filepath substringFromIndex:7];
                [[NSFileManager defaultManager] createDirectoryAtPath:tempipswdir withIntermediateDirectories:NO attributes:NULL error:NULL];

                self -> _downgradeButtonOut.enabled = false;
                self -> _selectIPSWoutlet.enabled = false;
                [self updateStatus:@"Verifying iPSW" color:[NSColor greenColor]];
                _uselessIndicator.indeterminate = true;
                    
                plistModifier *destinationCheck = NULL;
                
                if (strcmp([self ipswVersion:filepath], destinationCheck -> getPref(@"destinationFW").UTF8String) != 0) {
                        
                    [self updateStatus:@"Destination firmware of the connected device does not match with the selected iPSW" color:[NSColor redColor]];
                    self -> _downgradeButtonOut.enabled = false;
                    self -> _selectIPSWoutlet.enabled = true;
                    return;
                }
                
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    
                    plistModifier md5check;
                    
                    if ([md5check.getPref(@"skipMD5") isEqual:@"0"]) {
                        
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self updateStatus:@"Checking md5 of the iPSW..." color:[NSColor cyanColor]];
                        });
                        if ([self iPSWcheck:URL] != 0) {
                            return;
                        }
                    }
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        [self updateStatus:@"Successfully verified the iPSW" color:[NSColor cyanColor]];
                            
                    });
                    // if it's an A7 device, extract the iPSW (to patch bootchain)
                    if (strcmp(destinationCheck -> getPref(@"destinationFW").UTF8String, "8.4.1") == 0) {
                        NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
                        NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
                        [dict setValue:filepath forKey:@"32iPSWLoc"];
                        [dict writeToFile:preferencePlist atomically:YES];
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            self -> _downgradeButtonOut.enabled = true;
                            self -> _selectIPSWoutlet.enabled = true;
                        });
                        return;
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
        }
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
            
            dispatch_async(dispatch_get_main_queue(), ^(){
                [self -> _uselessIndicator startAnimation:nil];
                _dfuhelpoutlet.enabled = false;
                _dfuhelpoutlet.alphaValue = 0;
                _selectIPSWoutlet.enabled = false;
                _downgradeButtonOut.enabled = false;
                _versionLabel.alphaValue = 1;
            });
            static plistModifier destination;
            if (pwned && strcmp(destination.getPref(@"destinationFW").UTF8String, "10.3.3") == 0) {
                dispatch_async(dispatch_get_main_queue(), ^(){
                    [self updateStatus:@"Device was already pwned, skipping exploitation" color:[NSColor cyanColor]];
                });
            }
                
            else {
                dfuDevPtr -> freeDevice(); // need to free the device so that iPwnder32 can take over
                if ([self exploitDevice] != 0) {
                    return;
                }
                dfuDevPtr -> openConnection(5); // now reconnect to device
                dfuDevPtr -> setAllDeviceInfo(); // set the rest
            }
                
            dispatch_async(dispatch_get_main_queue(), ^(){
                [self updateStatus:@"Fetching OTA blob" color:[NSColor greenColor]];
            });
                    
            if ([self saveOTABlob] == -2) {
                dispatch_async(dispatch_get_main_queue(), ^(){
                    
                    [self updateStatus:[NSString stringWithFormat: @"Failed to save %@ OTA blob. Is it being signed?", destination.getPref(@"destinationFW")]  color: [NSColor redColor]];
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
                /*
                 ===================== BEWARE! ====================
                 || YOU ARE ABOUT TO WITNESS MADNESS !!!         ||
                 || MADNESS OF A GUY WHO COULDN'T FIGURE OUT     ||
                 || HOW TO PROPERLY USE completionHandler        ||
                 || THERE IS NO GOING BACK, YOU HAVE BEEN WARNED ||
                 ==================================================
                 */
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
                            
                            plistModifier destinationObject;
                            if (strcmp(destinationObject.getPref(@"destinationFW").UTF8String, "10.3.3") == 0) {
                                printf("printing dev info line 1012\n");
                                printf("SERIAL TAG -> %s\n", dfuDevPtr -> getDevInfo() ->srtg);
                                printf("HARDWARE MODEL -> %s\n", dfuDevPtr -> getHardwareModel());
                                if ([self restore64] == 0) {
                                    dispatch_async(dispatch_get_main_queue(), ^(){
                                        [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                        [self -> _uselessIndicator stopAnimation:nil];
                                        _selectIPSWoutlet.enabled = true;
                                                            
                                    });
                                }
                                else {
                                    dispatch_async(dispatch_get_main_queue(), ^(){
                                        [self -> _uselessIndicator stopAnimation:nil];
                                        [self updateStatus:@"Failed to restore device" color:[NSColor redColor]];
                                    });
                                }
                                return;
                            }
                            dfuDevPtr -> freeDevice();
                            if ([self restore32] == 0) {
                                dispatch_async(dispatch_get_main_queue(), ^() {
                                    [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                    [self -> _uselessIndicator stopAnimation:nil];
                                    _selectIPSWoutlet.enabled = true;
                                                        
                                });
                            }
                            else {
                                dispatch_async(dispatch_get_main_queue(), ^(){
                                    [self -> _uselessIndicator stopAnimation:nil];
                                    [self updateStatus:@"Failed to restore device" color:[NSColor redColor]];
                                });
                            }
                            });
                        }];
                        
                    }
                
                    else if (returnCode == NSAlertSecondButtonReturn) {
                
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        
            
                        plistModifier destinationObject;
                        if (strcmp(destinationObject.getPref(@"destinationFW").UTF8String, "10.3.3") == 0) {
                            printf("printing dev info line 1012\n");
                            printf("SERIAL TAG -> %s\n", dfuDevPtr -> getDevInfo() ->srtg);
                            printf("HARDWARE MODEL -> %s\n", dfuDevPtr -> getHardwareModel());
                            if ([self restore64] == 0) {
                                dispatch_async(dispatch_get_main_queue(), ^(){
                                    [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                    [self -> _uselessIndicator stopAnimation:nil];
                                    _selectIPSWoutlet.enabled = true;
                                                        
                                });
                            }
                            else {
                                dispatch_async(dispatch_get_main_queue(), ^(){
                                    [self -> _uselessIndicator stopAnimation:nil];
                                    [self updateStatus:@"Failed to restore device" color:[NSColor redColor]];
                                });
                            }
                            return;
                        }
                        dfuDevPtr -> freeDevice();
                        if ([self restore32] == 0) {
                            dispatch_async(dispatch_get_main_queue(), ^() {
                                [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                                [self -> _uselessIndicator stopAnimation:nil];
                                _selectIPSWoutlet.enabled = true;
                                                    
                            });
                        }
                        else {
                            dispatch_async(dispatch_get_main_queue(), ^(){
                                [self -> _uselessIndicator stopAnimation:nil];
                                [self updateStatus:@"Failed to restore device" color:[NSColor redColor]];
                            });
                        }
                                        
                    });
                    }
            }];
        });
    });
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
    
    cleanUp();
    
    _versionLabel.enabled = false;
    _versionLabel.alphaValue = 0;
    [_uselessIndicator setHidden:NO];
    [_uselessIndicator setIndeterminate:YES];
    [_uselessIndicator setUsesThreadedAnimation:YES];
    [self updateStatus:@"Waiting for a device in DFU Mode" color:[NSColor greenColor]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        printf("initial device scan started\n");
        while (!supported) {
            [self comeDiscover];
            usleep(500000);
        }
        dispatch_async(dispatch_get_main_queue(), ^(){
            self -> _versionLabel.alphaValue = 1.0;
            self -> _dfuhelpoutlet.enabled = false;
            self -> _dfuhelpoutlet.alphaValue = 0;
        });
    });
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

@end
