//
//  DFUDevice.hpp
//  LeetDown
//
//  Created by rA9stuff on 26.01.2022.
//

#ifndef DFUDevice_h
#define DFUDevice_h

#include <iostream>
#include "libirecovery.h"
#include <unistd.h>
#include <string>
#import <Foundation/Foundation.h>
#import "LeetDownMain.h"

class DFUDevice {

public:
    
    DFUDevice(): initECID(0) {}

    DFUDevice(irecv_client_t &givenClient, irecv_device_t &givenDevice): client(givenClient), device(givenDevice), initECID(0) {
        
        if (deviceConnected()) {
            openConnection(5);
            setAllDeviceInfo();
        }
    }
    // setters
    int openConnection(int);
    void setAllDeviceInfo();
    
    // getters
    const char* getDisplayName() { return this -> displayName; }
    const char* getHardwareModel() { return this -> hardwareModel; }
    const char* getProductType() { return this -> productType; }
    const struct irecv_device_info* getDevInfo() { return this -> devinfo; }
    irecv_client_t getClient() { return this -> client; }
    irecv_device_t getDevice() { return this -> device; }
    
    // functions
    bool deviceConnected();
    void freeDevice();
    bool checkPwn();
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
    
    uint64_t initECID;
};

#endif /* DFUDevice_h */
