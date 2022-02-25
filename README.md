# LeetDown
a GUI macOS app to downgrade compatible A6 and A7 devices to OTA signed firmwares.

* Latest compiled version can be found [here](https://github.com/rA9stuff/LeetDown/releases).
* [Official LeetDown Twitter account](https://twitter.com/LeetDownApp) for updates & support. 
* [Official LeetDown webpage](https://LeetDown.app)

![alt text](https://i.imgur.com/lBxab5S.png)


# Compatibility   

LeetDown is compatible with the following A6 SoC devices:

* iPhone 5
* iPad 4
   
LeetDown is compatible with the following A7 SoC devices:   
* iPhone 5s
* iPad Mini 2 (excluding J87AP)
* iPad Air


LeetDown can run on following environments:

| Intel Macs    | Apple Silicon Macs |
| ------------- |:-------------:|
| macOS 10.13+   | macOS 11.0 and higher |

# Downgrading A7 devices with an M1 mac?   

* Due to the USB stack of M1 macs, the device will disappear after LeetDown uploads iBSS. When you get the prompt `[+] Device was lost, reconnect the USB cable to your mac to resume the upload process`, do what it says and the restore will resume automatically.
* A6 devices are not affected by this issue.

# How to Use?

Mount the `LeetDown.dmg` and drag the `LeetDown.app` to your `/Applications` folder.

Follow the instructions shown in the app.

# F.A.Q.

Experimental Apple Silicon support: [As checkra1n team stated](https://checkra.in/news/2021/04/M1-announcement), Apple Silicon macs might have issues exploiting device or sending boot components. If you have problems with sending boot components, unplug your device after LeetDown sends iBSS, then plug it back in (LeetDown will wait for 5 seconds after sending each boot component to allow you to do this). If you have any other issues on Apple Silicon, feel free to open an issue.

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
Note: SSZipArchive is already placed inside the project, you can skip installing it via pods.   

# Having issues?

Sure, just open an issue ~~using [LeetDown issue template](https://github.com/rA9stuff/LeetDown/issues/new/choose)~~ please copy and paste the log from LeetDown's UI for now.

# Contributors  
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
