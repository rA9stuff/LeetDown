# LeetDown
    
a GUI macOS app to downgrade compatible A6 and A7 devices to OTA signed firmwares.   
    
[![CI](https://img.shields.io/github/actions/workflow/status/rA9stuff/LeetDown/ci.yml?branch=master&style=for-the-badge)](https://github.com/rA9stuff/LeetDown/actions)
[![Stars](https://img.shields.io/github/stars/rA9stuff/leetdown?style=for-the-badge)](https://github.com/rA9stuff/LeetDown/stargazers)
[![Licence](https://img.shields.io/github/license/rA9stuff/leetdown?style=for-the-badge)](https://github.com/rA9stuff/LeetDown/blob/master/LICENSE.md)
<br/>
<img align="right" src="https://i.imgur.com/5lI2lIo.png" width="130px" height="130px">
### Downloads
* [Latest notarized release (Recommended)](https://github.com/rA9stuff/LeetDown/releases)
* [Nightly builds (Experimental)](https://nightly.link/rA9stuff/LeetDown/workflows/ci/master)


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

# Installation

Mount the `LeetDown_[VERSION].dmg` and drag the `LeetDown.app` to your `/Applications` folder.

Follow the instructions shown in the app.

# Troubleshooting
### A7 devices and Apple Silicon Macs   

* Due to the USB stack of ASi macs, the device will disappear after LeetDown uploads iBSS. When you get the prompt `[+] Device was lost, reconnect the USB cable to your mac to resume the upload process`, do what it says and the restore will resume automatically.
* Make sure to reconnect the cable **to your mac**. You don't need to replug the cable to your iOS device.

### Stuck at exploiting or exploitation failure

* Make sure you're not using any USB Hubs or type-c to lightning cables. If your mac has only USB-C ports, use a lightning to type-a cable with a USB type-c to type-a converter.
* Make sure you're not running LeetDown under a virtual machine. Check [compatiblity](https://github.com/rA9stuff/LeetDown#compatibility) here.
* Re-enter DFU mode and try exploiting again with LeetDown.
* If it's still not working, [download iPwnder-lite](https://github.com/dora2-iOS/ipwnder_lite) and exploit your device manually.   

### Failed to restore device

* Update to latest iOS version with iTunes/Finder/idevicerestore then try again.
* Check if your USB cable is working fine.
* Try with a different USB port (or adapter if running on Apple Silicon).


# Build Instructions  
### With Xcode
`cd` to project directory   
run `pod install`   
open `.xcworkspace` and run it    

### With CLI
`cd` to project directory   
run `pod install`   
run `xcodebuild -workspace LeetDown.xcworkspace -scheme LeetDown_M` 

# Having issues?

* Enable debugging by clicking the box in LeetDown's settings.
* Open an issue, fill the template and attach the `LDLog.txt` to it from your `~/Documents` folder

# Supporters  
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
