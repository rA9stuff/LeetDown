//
//  NormalModeOperations.m
//  LiNUZE
//
//  Created by rA9stuff on 26.02.2023.
//  Copyright © 2023 rA9stuff. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "NormalModeOperations.h"
#include <plist/plist.h>

#define FORMAT_KEY_VALUE 1
#define FORMAT_XML 2

int tryNormalModeConnection(int tries) {
    
    idevice_t deviceNormal = NULL;
    const char* udid = NULL;
    int use_network = 0;
    for (int i = 0; i < tries; i++) {
        if (idevice_new_with_options(&deviceNormal, udid, (use_network) ? IDEVICE_LOOKUP_NETWORK : IDEVICE_LOOKUP_USBMUX) != IDEVICE_E_SUCCESS)
            return -1;
        usleep(500000);
    }
    idevice_free(deviceNormal);
    return 0;
}

int openNormalModeConnection(idevice_t& devptr, int tries) {
    
    const char* udid = NULL;
    int use_network = 0;
    idevice_error_t err;
    for (int i = 0; i < tries; i++) {
        err = idevice_new_with_options(&devptr, udid, (use_network) ? IDEVICE_LOOKUP_NETWORK : IDEVICE_LOOKUP_USBMUX);
        if (err == IDEVICE_E_SUCCESS)
            return 0;
        usleep(500000);
    }
    return -1;
}

NSString* getDeviceName(idevice_t& device, lockdownd_client_t &lockdown) {
    char* name = NULL;
    __block NSString* formattedName;
    lockdownd_error_t err = lockdownd_client_new(device, &lockdown, "dingus");
    
    if (err != LOCKDOWN_E_SUCCESS)
        return @"err";
        
    err = lockdownd_client_new_with_handshake(device, &lockdown, "dingus");
    
    if (err == LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING) {
        return @"err_pair";
    }
    
    lockdownd_get_device_name(lockdown, &name);
    @try {
        formattedName = [NSString stringWithUTF8String:name];
    }
    @catch (...) {
        formattedName = @"an unknown device";
    }
    @finally {
        return formattedName;
    }
}

char* queryKey(lockdownd_client_t &client, const char* key) {
    
    int format = FORMAT_KEY_VALUE;
    char *xml_doc = NULL;
    uint32_t xml_length;
    
    const char* domain = NULL;
    plist_t node;

    char* buf = NULL;
    uint32_t len = 0;
    
    if (lockdownd_get_value(client, domain, key, &node) == LOCKDOWN_E_SUCCESS) {
        if (node) {
            switch (format) {
            case FORMAT_XML:
                plist_to_xml(node, &xml_doc, &xml_length);
                printf("%s", xml_doc);
                free(xml_doc);
                break;
            case FORMAT_KEY_VALUE:
                plist_write_to_string(node, &buf, &len, PLIST_FORMAT_LIMD, PLIST_OPT_NONE);
                break;
            default:
                if (key != NULL)
                    plist_write_to_stream(node, stdout, PLIST_FORMAT_LIMD, PLIST_OPT_NONE);
            break;
            }
            plist_free(node);
            node = NULL;
        }
    }
    if (buf == NULL)
        return NULL;
    buf[strlen(buf) - 1] = '\0';
    return buf;
}
