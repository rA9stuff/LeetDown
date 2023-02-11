//
//  LDD.hpp
//  LeetDown
//
//  Created by rA9stuff on 26.01.2022.
//

#ifndef LDD_h
#define LDD_h

#include <iostream>
#include "libirecovery.h"
#include <unistd.h>
#include <string>
#import <Foundation/Foundation.h>
#import "LeetDownMain.h"

class LDD {

public:
    
    LDD(): initECID(0) {}

    LDD(irecv_client_t &givenClient, irecv_device_t &givenDevice): client(givenClient), device(givenDevice), initECID(0) {
        
        if (deviceConnected()) {
            openConnection(5);
            setAllDeviceInfo();
        }
    }
    // setters
    int openConnection(int);
    void setAllDeviceInfo();
    
    // getters
    const char* getDisplayName() { return displayName; }
    const char* getHardwareModel() { return hardwareModel; }
    const char* getProductType() { return productType; }
    const struct irecv_device_info* getDevInfo() { return devinfo; }
    irecv_client_t getClient() { return client; }
    irecv_device_t getDevice() { return device; }
    
    // functions
    bool deviceConnected();
    void freeDevice();
    bool checkPwn();
    const char* getDeviceMode();
    int sendFile(const char*, bool);
    int sendCommand(const char*, bool);
    void sendDataToNSA();
    
private:
    irecv_client_t client;
    irecv_device_t device;
    const struct irecv_device_info *devinfo;
    const char *displayName;
    const char *hardwareModel;
    const char* productType;
    const char* deviceMode;
    
    uint64_t initECID;
};

#endif /* LDD_h */
