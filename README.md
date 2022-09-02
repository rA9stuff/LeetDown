# LeetDown
a GUI macOS app to downgrade compatible A6 and A7 devices to OTA signed firmwares.

* Latest compiled version can be found [here](https://github.com/rA9stuff/LeetDown/releases).
* [Official LeetDown Twitter account](https://twitter.com/LeetDownApp) for updates & support. 
* [Official LeetDown webpage](https://LeetDown.app)

![alt text](https://i.imgur.com/lBxab5S.png)


# Compatibility   

### iOS Device Compatibility

| iOS 8.4.1 Downgrade | iOS 10.3.3 Downgrade |
| :---         | :---         |
| iPhone 5   | iPhone 5s   |
| iPad 4   | iPad Mini 2 (excluding J87AP)   |
| -   | iPad Air   |
   
   
### macOS Compatibility

| Intel Macs    | ASi Macs (Rosetta 2) |
| --- | --- |
| macOS 10.13 +   | macOS 11.0 + |

### Virtual Machines and Hackintosh Systems
LeetDown is **not** compatible with virtual machines. Some hackintosh systems were successful running LeetDown, though, exploiting issues you encounter on environments other than real Mac hardware is up to you to resolve. Please do not open an issue for this.

# Troubleshooting
### A7 devices and Apple Silicon Macs   

* Due to the USB stack of ASi macs, the device will disappear after LeetDown uploads iBSS. When you get the prompt `[+] Device was lost, reconnect the USB cable to your mac to resume the upload process`, do what it says and the restore will resume automatically.
* Make sure to reconnect the cable **to your mac**. You don't need to replug the cable to your iOS device.

### Stuck at exploiting or exploitation failure

* Make sure you're not using any USB Hubs or type-c to lightning cables. If your mac has only USB-C ports, use a lightning to type-a cable with a USB type-c to type-a converter.
* Make sure you're not running LeetDown under a virtual machine. Check [compatiblity](https://github.com/rA9stuff/LeetDown#compatibility) here.
* Re-enter DFU mode and try exploiting again with LeetDown.
* If it's still not working, [download iPwnder-lite](https://github.com/dora2-iOS/ipwnder_lite) and exploit your device manually.   

# Installation

Mount the `LeetDown_[VERSION].dmg` and drag the `LeetDown.app` to your `/Applications` folder.

Follow the instructions shown in the app.


# Build Instructions  
LeetDown depends on the following libraries:   
* libcrypto (get it via `brew install openssl`)
* [libirecovery](https://github.com/libimobiledevice/libirecovery)
* [libplist](https://github.com/libimobiledevice/libplist)
* libusb (get it via `brew install libusb`)
* [libusbmuxd](https://github.com/libimobiledevice/libusbmuxd)   
ps: If you don't want to compile `libirecovery`, `libplist` and `libusbmuxd` manually, [Nikias Bassen](https://twitter.com/pimskeks) has a [script](https://twitter.com/pimskeks/status/1486147309247283200?s=20&t=nvx4MIq3dSS-zMGE5dBLuw) available that can build all libimobiledevice tools automatically.

Place the libraries in any folder (preferably inside "Frameworks" to build it statically) in your environment, then;
* Project -> Build Settings -> Library Search Paths -> path_to_your_folder

LeetDown depends on the following frameworks:
* AFNetworking
* SSZipArchive

You can install them automatically with cocoapods.   
Note: A modified version of SSZipArchive is already placed inside the project, skip installing it via pods.   

# Having issues?

* Enable debugging by clicking the box in LeetDown's settings.
* Open an issue, fill the template and attach the `LDLog.txt` to it from your `~/Documents` folder

# Donators  
* Will Kellner
* qqjqqj

# Credits:

* [@axi0mX](https://twitter.com/axi0mX) for checkm8 exploit.
* [@tihmstar](https://twitter.com/tihmstar) for futurerestore.
* [@Cryptiiiic](https://twitter.com/Cryptiiiic) for updated futurerestore.
* [@\_m1sta](https://twitter.com/_m1sta) for updated futurerestore.
* [@dora2ios](https://twitter.com/dora2ios) for iPwnder-lite.
* [@mosk_i](https://twitter.com/mosk_i) for iBoot patches and internal testing.
* [@libimobiledev](https://twitter.com/libimobiledev) for libirecovery.
* [@ConsoleLogLuke](https://twitter.com/ConsoleLogLuke) for helping with the dependencies and scripts for versions < 2.0
* [ZipArchive](https://github.com/ZipArchive/ZipArchive) for SSZipArchive. 
* [AFNetworking](https://github.com/AFNetworking/AFNetworking) for AFNetworking.
* [@alitek123](https://twitter.com/alitek123) for OTA BuildManifests. 
* [@exploit3dguy](https://twitter.com/exploit3dguy) for private testing.
* [@m3t0ski](https://twitter.com/m3t0ski) for private testing.
* [@AyyItzRob123](https://twitter.com/AyyItzRob123) for private testing.
* [Mini-Exploit](https://github.com/Mini-Exploit) for private testing.
