#import "ViewController.h"
#include "libirecovery.h"
#include <stdlib.h>
#include "SSZipArchive/SSZipArchive.h"
#define USB_TIMEOUT 10000
#import "DFUHelperViewController.h"


uint64_t ecid = 0;


int received_cb(irecv_client_t client, const irecv_event_t* event);
int progress_cb(irecv_client_t client, const irecv_event_t* event);
int precommand_cb(irecv_client_t client, const irecv_event_t* event);
int postcommand_cb(irecv_client_t client, const irecv_event_t* event);
bool connected = false;


enum {
    kNoAction,
    kResetDevice,
    kStartShell,
    kSendCommand,
    kSendFile,
    kSendExploit,
    kSendScript,
    kShowMode,
    kRebootToNormalMode,
    kQueryInfo,
    kListDevices
};


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

int saveOTABlob(irecv_client_t client, irecv_device_t device) {
    
    client = NULL;
    device = NULL;
    
    irecv_error_t erro = irecv_open_with_ecid(&client, ecid);
    printf("Attempting to connect... \n");
    if (erro == IRECV_E_UNSUPPORTED) {
        fprintf(stderr, "ERROR: %s\n", irecv_strerror(erro));
    }
    else if (erro != IRECV_E_SUCCESS) {
        usleep(500000);
    }
    else {
        connected = true;
        irecv_devices_get_device_by_client(client, &device);
        const struct irecv_device_info *devinfo = irecv_get_device_info(client);
    

    irecv_devices_get_device_by_client(client, &device);
            
    NSString *devecid = [NSString stringWithFormat:@"%llu", devinfo ->ecid];
    NSString *devmodel = [NSString stringWithFormat:@"%s", device ->product_type];
    NSString *apnonce = [NSString stringWithFormat:@"%@", NSNonce(devinfo -> ap_nonce, devinfo -> ap_nonce_size)];
    NSString *board = [NSString stringWithFormat:@"%s", device ->hardware_model];
    NSMutableString *blobname = [[[[[[[[devecid stringByAppendingString:@"_"] stringByAppendingString: devmodel] stringByAppendingString:@"_"] stringByAppendingString: board] stringByAppendingString:@"_10.3.3-14G60_"] stringByAppendingString:apnonce] stringByAppendingString:@".shsh"] mutableCopy];
    irecv_close(client);
    
    NSTask *saveOTA = [[NSTask alloc]init];
    NSString *RSpath = [[NSBundle mainBundle] resourcePath];
    NSString *tsscheckerpath = [RSpath stringByAppendingString:@"/LDResources/Binaries/tsschecker"];
    saveOTA.launchPath = tsscheckerpath;
    
    
    NSString *buildmanifest = NULL;
    buildmanifest = [RSpath stringByAppendingString:@"/LDResources/Buildmanifests/"];
    buildmanifest = [buildmanifest stringByAppendingString:devmodel];
    buildmanifest = [buildmanifest stringByAppendingString:@".plist"];
    
    saveOTA.arguments = @[@"-m", buildmanifest, @"-e", devecid, @"-d", devmodel, @"-s", @"-B", board, @"--apnonce", apnonce, @"--save-path", [RSpath stringByAppendingString:@"/LDResources"]];
    [saveOTA launch];
    [saveOTA waitUntilExit];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    [fm moveItemAtPath:[[RSpath stringByAppendingString:@"/LDResources/"] stringByAppendingString:blobname]  toPath:[RSpath stringByAppendingString:@"/LDResources/blob.shsh"] error:NULL];
    }
    return 0;
}

void cleanUp(void) {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *blobLocation = [[NSString stringWithFormat:@"%@", [[NSBundle mainBundle] resourcePath]] stringByAppendingString:@"/LDResources/blob.shsh"];
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



int restore(irecv_client_t client, irecv_device_t device) {
    
    client = NULL;
    device = NULL;
    connected = false;
    
    
    while (!connected) {
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        printf("Attempting to connect... \n");
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        if (error == IRECV_E_SUCCESS) {
            connected = true;
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
    NSString *ticket = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/blob.shsh"];
    
    
    if (strcmp(boardcmp, "n51ap") == 0 || strcmp(boardcmp, "n53ap") == 0) {
        
        irecv_send_file(client, iPhoneLDBoot, 1);
        irecv_send_command(client, "setpicture 0");
        irecv_send_command(client, "bgcolor 255 255 255");
        
        restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"-m", bm, @"-s", sep, tempipswdir];
    }

    else if (strcmp(boardcmp, "j71ap") == 0 || strcmp(boardcmp, "j85ap") == 0) {
        
        irecv_send_file(client, iPadLDBoot, 1);
        irecv_send_command(client, "setpicture 0");
        irecv_send_command(client, "bgcolor 255 255 255");
        
        restore.arguments = @[@"-t", ticket, @"-p", bm, @"-m", bm, @"-s", sep, tempipswdir, @"--no-baseband"];
        
    }
    else if (strcmp(boardcmp, "j72ap") == 0 || strcmp(boardcmp, "j73ap") == 0 || strcmp(boardcmp, "j86ap") == 0 || strcmp(boardcmp, "j87ap") == 0) {
        
        irecv_send_file(client, iPadLDBoot, 1);
        irecv_send_command(client, "setpicture 0");
        irecv_send_command(client, "bgcolor 255 255 255");
        
        restore.arguments = @[@"-t", ticket, @"-b", bb, @"-p", bm, @"-m", bm, @"-s", sep, tempipswdir];
        
    }
    irecv_close(client);

    sleep(5);
    [restore launch];
    [restore waitUntilExit];
    return [restore terminationStatus];
}

bool ispwned(irecv_client_t client, irecv_device_t device) {
    
    client = NULL;
    device = NULL;
    
    
    
    for (int i = 0; i < 5; i++) {
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        printf("Attempting to connect... \n");
        if (i == 4) {
            return false;
        }
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        else if (error == IRECV_E_SUCCESS){
            break;
        }
    }
    irecv_devices_get_device_by_client(client, &device);
    const struct irecv_device_info *devinfo = irecv_get_device_info(client);
        
    NSString *pwnstr = [NSString stringWithFormat:@"%s", devinfo -> serial_string];
    if ([pwnstr containsString:@"PWND:[checkm8]"]) {
        irecv_close(client);
        return true;
    }
    else {
        irecv_close(client);
        return false;
    }
    return false;
}

void patchFiles(void) {
    
    
    irecv_client_t client = NULL;
    irecv_device_t device = NULL;
    connected = false;
   
    while (!connected) {
        irecv_error_t error = irecv_open_with_ecid(&client, ecid);
        printf("Attempting to connect... \n");
        if (error == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(error));
        }
        else if (error != IRECV_E_SUCCESS) {
            usleep(500000);
        }
        if (error == IRECV_E_SUCCESS) {
            connected = true;
            irecv_devices_get_device_by_client(client, &device);
        }
    }
    
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
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"Patches/ibss_ipad4.patch"]];
        [ibsspatch launch];
        [ibsspatch waitUntilExit];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"Patches/ibec_ipad4.patch"]];
        [ibecpatch launch];
        [ibecpatch waitUntilExit];
    }
    
    else if (strcmp(boardcmp, "j85ap") == 0 || strcmp(boardcmp, "j86ap") == 0 || strcmp(boardcmp, "j87ap") == 0) {
        ibsspatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4b.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBSS.ipad4b.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"Patches/ibss_ipad4b.patch"]];
        [ibsspatch launch];
        [ibsspatch waitUntilExit];
        ibecpatch.arguments = @[[tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4b.RELEASE.im4p"], [tempipswdir stringByAppendingString:@"/Firmware/dfu/iBEC.ipad4b.RELEASE.im4p"], [LDResourcesPath stringByAppendingString:@"Patches/ibec_ipad4b.patch"]];
        [ibecpatch launch];
        [ibecpatch waitUntilExit];
        
    }
}

@implementation ViewController

bool firstline = true;
bool pwned = false;
- (IBAction)dfuhelperact:(id)sender {
    
    // got this trick from Matty's Ramiel app ;)
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    NSViewController *yourViewController = [storyboard instantiateControllerWithIdentifier:@"DFUHelper"];
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self.view.window.contentViewController presentViewControllerAsSheet:yourViewController];
    });
    
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
    });
}

int supported = 0;


- (void) PrintDevInfo:(irecv_client_t)tempcli device:(irecv_device_t)tempdev {

    tempcli = NULL;
    tempdev = NULL;
    
    irecv_error_t erro = irecv_open_with_ecid(&tempcli, ecid);
    printf("Attempting to connect... \n");
    if (erro == IRECV_E_UNSUPPORTED) {
        fprintf(stderr, "ERROR: %s\n", irecv_strerror(erro));
    }
    else if (erro != IRECV_E_SUCCESS) {
        usleep(500000);
    }
    else {
        connected = true;
        irecv_devices_get_device_by_client(tempcli, &tempdev);
        const struct irecv_device_info *devinfo = irecv_get_device_info(tempcli);
        
        NSString *stag = [NSString stringWithFormat:@"%s", devinfo -> serial_string];
        if ([stag containsString:@"PWND:[checkm8]"]) {
            pwned = true;
        }
        [self infoLog: @"\n\n============== DEVICE INFO ==============\n" color:[NSColor cyanColor]];
        [self infoLog: @"\nModel Name: " color:[NSColor cyanColor]];
        [self infoLog: [NSString stringWithFormat:@"%s", tempdev -> display_name] color:[NSColor greenColor]];
        [self infoLog: @"\nHardware Model: " color:[NSColor cyanColor]];
        [self infoLog: [NSString stringWithFormat:@"%s", tempdev -> hardware_model] color:[NSColor greenColor]];
        [self infoLog: @"\nECID: " color:[NSColor cyanColor]];
        [self infoLog: [NSString stringWithFormat:@"%llu", devinfo -> ecid] color:[NSColor greenColor]];
            
        [self infoLog: @"\nAPNonce:" color:[NSColor cyanColor]];
        [self infoLog: [NSString stringWithFormat:@"%@", NSNonce(devinfo -> ap_nonce, devinfo -> ap_nonce_size)] color:[NSColor greenColor]];
        [self infoLog:@"\nSEPNonce:" color:[NSColor cyanColor]];
        [self infoLog: [NSString stringWithFormat:@"%@", NSNonce(devinfo -> sep_nonce, devinfo -> sep_nonce_size)] color:[NSColor greenColor]];
        [self infoLog:@"\nCPID: " color:[NSColor cyanColor]];
        [self infoLog: [NSString stringWithFormat:@"%@", NSCPID(&devinfo -> cpid)] color:[NSColor greenColor]];
        [self infoLog:@"\nPwned: " color:[NSColor cyanColor]];
        irecv_close(tempcli);
        if (ispwned(tempcli, tempdev)) {
            [self infoLog: @"Yes" color:[NSColor greenColor]];
        }
        else {
            [self infoLog: @"No" color:[NSColor greenColor]];
        }
        [self infoLog: @"\n\n=======================================" color:[NSColor cyanColor]];
    }
}

- (void) sendCommand:(irecv_client_t)cli device:(irecv_device_t)dev command:(const char*)cmd {
    
    irecv_error_t errr;
    printf("Attempting to connect... \n");
    errr = irecv_open_with_ecid(&cli, ecid);

    int __block ret, mode;

    printf("Attempting to send a file... \n");
    if (errr == IRECV_E_UNSUPPORTED) {
        fprintf(stderr, "ERROR: %s\n", irecv_strerror(errr));
    }
    else if (errr != IRECV_E_SUCCESS) {
    usleep(500000);
    }
    else {
        connected = true;
    }


    ret = irecv_get_mode(cli, &mode);
        
    if (ret == IRECV_E_SUCCESS) {
            
        irecv_devices_get_device_by_client(cli, &dev);
        irecv_send_command(cli, cmd);
    }
    irecv_close(cli);
}

- (void) sendFile:(irecv_client_t)clii device:(irecv_device_t)devv filename:(NSString*)file {
    
    connected = false;
    irecv_error_t errr;
    int __block ret, mode;
    const char *filename = [file cStringUsingEncoding:NSASCIIStringEncoding];
    devv = NULL;
    
    while (!connected) {
        
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self updateStatus:@"Waiting for the device to connect" color:[NSColor yellowColor]];
        });
        printf("Attempting to connect... \n");
        errr = irecv_open_with_ecid(&clii, ecid);
        if (errr == IRECV_E_UNSUPPORTED) {
            fprintf(stderr, "ERROR: %s\n", irecv_strerror(errr));
        }
        else if (errr != IRECV_E_SUCCESS) {
            usleep(500000);
            if (clii != NULL) {
                irecv_close(clii);
                clii = NULL;
            }
        }
        else {
            connected = true;
        }
    }
    
    ret = irecv_get_mode(clii, &mode);
        
    if (ret == IRECV_E_SUCCESS) {

        irecv_send_file(clii, filename, 1);
        dispatch_async(dispatch_get_main_queue(), ^(){
            [self updateStatus:[NSString stringWithFormat:@"Sending %@", file] color:[NSColor greenColor]];
        });
    }
    irecv_close(clii);
    
}

bool firstrun = true;
bool newdevice = true;
unsigned long long devCompStr;

- (void) Discover:(irecv_client_t)client device:(irecv_device_t)dev {
    

    
    client = NULL;

    printf("Attempting to connect... \n");

    irecv_error_t err = irecv_open_with_ecid(&client, ecid);
    
    if (err == IRECV_E_UNSUPPORTED) {
        fprintf(stderr, "ERROR: %s\n", irecv_strerror(err));
            
    }
    
    else if (err != IRECV_E_SUCCESS)
        usleep(500000);
    else {
            
        irecv_devices_get_device_by_client(client, &dev);
        const struct irecv_device_info *devinfo = irecv_get_device_info(client);
        if(!(devinfo->srtg)){
            [self updateStatus:[NSString stringWithFormat:@"Device connected in wrong mode, please put your device in DFU mode to proceed"] color:[NSColor redColor]];
            
        }
        else {
            
            dispatch_async(dispatch_get_main_queue(), ^(){
                _dfuhelpoutlet.enabled = false;
                _dfuhelpoutlet.alphaValue = 0;
            });
            
            NSString *NScpid = [NSString stringWithFormat:@"%@", NSCPID(&devinfo -> cpid)];
            const char *cpid = [NScpid cStringUsingEncoding:NSASCIIStringEncoding];
        
            if (strcmp(cpid, "8960") == 0 || strcmp(cpid, "8965") == 0) {
                
                supported = true;
                dispatch_async(dispatch_get_main_queue(), ^(){
                    self -> _selectIPSWoutlet.enabled = true;
                    
                    [self updateStatus:[NSString stringWithFormat: @"%s is supported", dev -> display_name] color:[NSColor greenColor]];
                
                    irecv_close(client);
                    if (firstrun) {
                        [self PrintDevInfo: client device: dev];
                        firstrun = false;
                    }
                });
            }
            
            else {
            // if the newly connected device has the same ECID of the previous one, don't display this message.
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
                    return;
                }
                
                if (devCompStr == devinfo -> ecid) {
                    irecv_close(client);
                    return;
                }
            }
        }
    }
}


- (IBAction)selectIPSW:(id)sender {
    
    cleanUp();
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    NSArray* fileTypes = [NSArray arrayWithObjects:@"ipsw", @"IPSW", nil];
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setAllowedFileTypes:fileTypes];

    if ( [openDlg runModal] == NSModalResponseOK ) {
        
        for( NSURL* URL in [openDlg URLs] ) {

            NSString *filepath = URL.absoluteString;
            filepath = [filepath substringFromIndex:7];
            NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
            [[NSFileManager defaultManager] createDirectoryAtPath:tempipswdir withIntermediateDirectories:NO attributes:NULL error:NULL];
        
            [self updateStatus:[NSString stringWithFormat:@"iPSW selected at %@ and being extracted to %@", filepath, tempipswdir] color:[NSColor cyanColor]];

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                
                dispatch_async(dispatch_get_main_queue(), ^(){
                    self -> _selectIPSWoutlet.enabled = false;
                    self -> _downgradeButtonOut.enabled = false;
                    [self updateStatus:@"Extracting the iPSW please wait..." color:[NSColor greenColor]];
                    [self -> _uselessIndicator startAnimation:nil];
                });
            
                [SSZipArchive unzipFileAtPath:filepath toDestination: tempipswdir];
                
        
                dispatch_async(dispatch_get_main_queue(), ^(){
                    self -> _downgradeButtonOut.enabled = true;
                    self -> _selectIPSWoutlet.enabled = true;
                    [self updateStatus:@"Successfully extracted the iPSW" color:[NSColor greenColor]];
                    [self->_uselessIndicator stopAnimation:nil];
                });
            });
        }
    }
}

- (IBAction)downgradeButtonAct:(id)sender {
    
    
    
    irecv_device_t dev = NULL;
    irecv_client_t cli = NULL;
    
    NSString *tempipswdir = [[NSString stringWithFormat:@"%@", NSTemporaryDirectory()] stringByAppendingString:@"iPSW"];
    
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
                });
                
                if (pwned) {
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        [self updateStatus:@"Device was already pwned, skipping exploitation" color:[NSColor cyanColor]];
                    });
                }
                else {
                    
                    dispatch_async(dispatch_get_main_queue(), ^(){
                        [self updateStatus:@"Running checkm8 exploit" color:[NSColor greenColor]];
                    });
                    
                    NSTask *exploit = [[NSTask alloc] init];
                    [exploit setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LDResources/Binaries/iPwnder32"]];
                    [exploit setArguments:@[@"-p"]];

                    NSPipe * out = [NSPipe pipe];
                    [exploit setStandardOutput:out];

                    [exploit launch];
                    [exploit waitUntilExit];
                    [exploit release];
                    
                    if (ispwned(cli, dev)) {
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self updateStatus:@"Successfully exploited device!" color:[NSColor cyanColor]];
                        });
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self -> _uselessIndicator stopAnimation:nil];
                            [self updateStatus:@"Failed to exploit device, please re-enter DFU mode and try again" color:[NSColor redColor]];
                        });
                        return;
                    }
                }
                        
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self updateStatus:@"Patching bootchain" color:[NSColor greenColor]];
                        });
                        sleep(1);
                        patchFiles();
                        
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self updateStatus:@"Fetching iOS 10.3.3 OTA blob..." color:[NSColor greenColor]];
                        });
                        
                        saveOTABlob(cli, dev);
                    
                        [self sendFile:cli device:dev filename:@"/dev/null"];
                        sleep(5);
                        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBSS.iphone6.release.im4p"]];
                        sleep(5);
                        [self sendFile:cli device:dev filename: [tempipswdir stringByAppendingString:@"/Firmware/DFU/iBEC.iphone6.release.im4p"]];
                        dispatch_async(dispatch_get_main_queue(), ^(){
                            [self updateStatus:@"Restoring..." color:[NSColor greenColor]];
                        });
                        if (restore(cli, dev) == 0) {
                            dispatch_async(dispatch_get_main_queue(), ^(){
                                [self -> _uselessIndicator stopAnimation:nil];
                                [self updateStatus:@"Restore succeeded!" color:[NSColor cyanColor]];
                            });
                        }
                        else {
                            dispatch_async(dispatch_get_main_queue(), ^(){
                                [self -> _uselessIndicator stopAnimation:nil];
                                [self updateStatus:@"Failed to restore device" color:[NSColor redColor]];
                            });
                        }
                cleanUp();
            });
        }
        
        else if (returnCode == NSAlertSecondButtonReturn) {
            [self updateStatus:@"Restore was cancelled by user" color:[NSColor greenColor]];
            return;
        }
    }];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    
    cleanUp();
    [_uselessIndicator setHidden:NO];
    [_uselessIndicator setIndeterminate:YES];
    [_uselessIndicator setUsesThreadedAnimation:YES];
    [self updateStatus:@"Waiting for a device in DFU Mode" color:[NSColor greenColor]];
    int randNum = arc4random_uniform(1000);
    if (randNum == 10) {
        _header.stringValue = @"1337Down";
        _ramiel.stringValue = @"Okay Ramiel did it first but you have 1 in a 1000 chances of seeing\n 1337Down";
    }
    
    irecv_device_t tempdev = NULL;
    irecv_client_t tempcli = NULL;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!supported) {
            
            [self Discover: tempcli device: tempdev];
            sleep(1);
        }
        irecv_close(tempcli);
    });
     
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    
    // Update the view, if already loaded.
}

@end
