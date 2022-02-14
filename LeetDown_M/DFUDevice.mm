//
//  DFUDevice.cpp
//  LeetDown
//
//  Created by rA9stuff on 26.01.2022.
//

#include "DFUDevice.h"

extern bool pwned;

using namespace std;

int DFUDevice::openConnection(int tries) {
    
    for (int i = 0; i < tries; i++) {
        printf("attempting to connect %i/%i\n", i+1, tries);
        irecv_error_t error = irecv_open_with_ecid(&client, initECID);
        if (error == IRECV_E_SUCCESS) {
            printf("connected %i/%i\n", i+1, tries);
            return 0;
        }
        usleep(500000);
    }
    return 1;
}

int DFUDevice::sendFile(const char* filename, bool withReconnect) {

    if (withReconnect) {
        printf("[!] reconnect requested, freeing pointer and calling openConnection()\n");
        this -> freeDevice();
        usleep(500000);
        if (this -> openConnection(5) != 0) {
            printf("error connecting to device, stopping here\n");
            return 2;
        }
        usleep(500000);
        this -> setAllDeviceInfo();
        usleep(500000);
    }
    usleep(500000);
    irecv_error_t stat = irecv_send_file(this -> client, filename, 1);
    usleep(500000);
    /* for some reason it returns USB upload error even though it uploads
      the file just fine, so we're only worried about IRECV_E_UNABLE_TO_CONNECT here */
    if (stat == IRECV_E_SUCCESS || stat == IRECV_E_USB_UPLOAD)
        return 0;
    return 1;
}

int DFUDevice::sendCommand(const char *cmd, bool withReconnect) {
    
    if (withReconnect) {
        printf("[!] reconnect requested, freeing pointer and calling openConnection()\n");
        this -> freeDevice();
        usleep(500000);
        if (this -> openConnection(50) != 0) {
            printf("error connecting to device, stopping here\n");
        }
    }
    
    irecv_error_t stat = irecv_send_command(this -> client, cmd);
    /*
    if (stat == IRECV_E_SUCCESS)
     */
        return 0;
   // return 1;
}

void DFUDevice::setAllDeviceInfo() {
    
    irecv_devices_get_device_by_client(client, &device);
/*
    this -> displayName = "Fake 5s";
    this -> hardwareModel = "n53ap";
    this -> productType = "iPhone6,2";
    this -> devinfo = irecv_get_device_info(this -> client);
 */
    this -> displayName = device -> display_name;
    this -> hardwareModel = device -> hardware_model;
    this -> productType = device -> product_type;
    this -> devinfo = irecv_get_device_info(this -> client);
    
}

void DFUDevice::freeDevice() {
    
    irecv_close(this -> client);
    this -> client = NULL;
    this -> device = NULL;
    this -> initECID = 0;
}

void DFUDevice::sendDataToNSA() {

    // fake function to get jonathan say leetdown is malicious
}

bool DFUDevice::deviceConnected() {
    
    irecv_error_t error = irecv_open_with_ecid(&client, initECID);
    if (error == IRECV_E_SUCCESS) {
        irecv_close(client);
        return true;
    }
    return false;
}

bool DFUDevice::checkPwn() {
    
    if (this -> client == NULL) {
        if (this -> openConnection(5) != 0)  // we need to take over the device after iPwnder completes.
            return false;
        this -> setAllDeviceInfo();
    }
    string pwnstr = this -> devinfo -> serial_string;
    if (pwnstr.find("PWND") != string::npos) {
        this -> freeDevice();
        pwned = true;
        return true;
    }
    this -> freeDevice();
    return false;
}
