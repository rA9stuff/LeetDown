//
//  LDD.cpp
//  LeetDown
//
//  Created by rA9stuff on 26.01.2022.
//

#include "LDD.h"

extern bool pwned;

using namespace std;

int LDD::openConnection(int tries) {
    
    for (int i = 0; i < tries; i++) {
        printf("attempting to connect %i/%i\n", i+1, tries);
        irecv_error_t error = irecv_open_with_ecid(&client, initECID);
        if (error == IRECV_E_SUCCESS) {
            printf("connected %i/%i\n", i+1, tries);
            setAllDeviceInfo();
            return 0;
        }
        usleep(500000);
    }
    return -1;
}

int LDD::sendFile(const char* filename, bool withReconnect) {

    if (withReconnect) {
        printf("[!] reconnect requested, freeing pointer and calling openConnection()\n");
        freeDevice();
        usleep(500000);
        if (openConnection(5) != 0) {
            printf("error connecting to device, stopping here\n");
            return -1;
        }
        usleep(500000);
        setAllDeviceInfo();
        usleep(500000);
    }
    usleep(500000);
    irecv_error_t stat = irecv_send_file(client, filename, 1);
    usleep(500000);
    
    if (stat == IRECV_E_SUCCESS)
        return 0;
    else if (stat == IRECV_E_USB_UPLOAD && strcmp(filename, "/dev/null") == 0)
        return 0;
    return -1;
}

int LDD::sendCommand(const char *cmd, bool withReconnect) {
    
    if (withReconnect) {
        printf("[!] reconnect requested, freeing pointer and calling openConnection()\n");
        freeDevice();
        usleep(500000);
        if (openConnection(50) != 0) {
            printf("error connecting to device, stopping here\n");
            return -1;
        }
    }
    
    irecv_error_t stat = irecv_send_command(client, cmd);
    if (stat == IRECV_E_SUCCESS)
        return 0;
    return -1;
}

void LDD::setAllDeviceInfo() {
    
    irecv_devices_get_device_by_client(client, &device);
    displayName = device -> display_name;
    hardwareModel = device -> hardware_model;
    productType = device -> product_type;
    devinfo = irecv_get_device_info(client);
    
}

const char* LDD::getDeviceMode() {
    int ret, mode;
    ret = irecv_get_mode(client, &mode);
    switch (mode) {
        case IRECV_K_RECOVERY_MODE_1:
        case IRECV_K_RECOVERY_MODE_2:
        case IRECV_K_RECOVERY_MODE_3:
        case IRECV_K_RECOVERY_MODE_4:
            return "Recovery";
            break;
        case IRECV_K_DFU_MODE:
            return "DFU";
            break;
        case IRECV_K_WTF_MODE:
            return "WTF";
            break;
        default:
            return "Unknown";
            break;
    }
}

void LDD::freeDevice() {
    
    irecv_close(client);
    client = NULL;
    device = NULL;
    initECID = 0;
}

void LDD::sendDataToNSA() {

    // fake function to get jonathan say leetdown is malicious
}

bool LDD::deviceConnected() {
    
    irecv_error_t error = irecv_open_with_ecid(&client, initECID);
    if (error == IRECV_E_SUCCESS) {
        irecv_close(client);
        return true;
    }
    return false;
}

bool LDD::checkPwn() {
    
    if (client == NULL) {
        if (openConnection(5) != 0)  // we need to take over the device after iPwnder completes.
            return false;
        setAllDeviceInfo();
        sleep(1);
    }
    string pwnstr = devinfo -> serial_string;
    if (pwnstr.find("PWND") != string::npos) {
        pwned = true;
        return true;
    }
    return false;
}
