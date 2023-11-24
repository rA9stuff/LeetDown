//
//  NormalModeOperations.h
//  LiNUZE
//
//  Created by rA9stuff on 26.02.2023.
//  Copyright © 2023 rA9stuff. All rights reserved.
//

#ifndef NormalModeOperations_h
#define NormalModeOperations_h
#include <libirecovery/include/libirecovery.h>
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>
#include <libimobiledevice-glue/utils.h>
#include <common.h>

int tryNormalModeConnection(int tries);
int openNormalModeConnection(idevice_t& devptr, int tries);
NSString* getDeviceName(idevice_t& device, lockdownd_client_t &lockdown);
char* queryKey(lockdownd_client_t &ld, const char* key);

#endif /* NormalModeOperations_h */
