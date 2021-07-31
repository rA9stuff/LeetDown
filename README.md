# LeetDown

[Official LeetDown Twitter account](https://twitter.com/LeetDownApp) for updates & support. 


an OTA Downgrade Tool for A7 devices.

Supported devices are iPhone 5s, iPad Air and iPad Mini 2. iPad Mini 3 will never be supported as apple doesn't sign 10.3.3 OTA for it.

Latest compiled version can be found [here](https://github.com/rA9stuff/LeetDown/releases).

![alt text](https://i.imgur.com/6oNI4kV.png)

# How to Use?

Mount the `LeetDown.dmg` and drag the `LeetDown.app` to your `/Applications` folder.

Follow the instructions shown in the app.

# F.A.Q.

Experimental Apple Silicon support: [As checkra1n team stated](https://checkra.in/news/2021/04/M1-announcement), Apple Silicon macs might have issues exploiting device or sending boot components. If you have problems with sending boot components, unplug your device after LeetDown sends iBSS, then plug it back in (LeetDown will wait for 5 seconds after sending each boot component to allow you to do this). If you have any other issues on Apple Silicon, feel free to open an issue.

# Having issues?

Sure, just open an issue that includes which device you're trying to restore, your host environment and version.

# Huge Thanks To:

* [@axi0mX](https://twitter.com/axi0mX) for the legendary checkm8 exploit.

* [@tihmstar](https://twitter.com/tihmstar) for futurerestore.

* [@dora2ios](https://twitter.com/dora2ios) for "iPwnder32" which works amazingly well on A7 SoC.

* [@mosk_i](https://twitter.com/mosk_i) for boot component patches and notarizing the app (honestly can't thank him enough for this).

* [@libimobiledev](https://twitter.com/libimobiledev) for libirecovery.

* [@ConsoleLogLuke](https://twitter.com/ConsoleLogLuke) for helping with the dependencies and scripts :) (both are purposeless with the version 2.0 but I'll keep it here anyways for his help on the initial release).

* [ZipArchive](https://github.com/ZipArchive/ZipArchive) for SSZipArchive. 
