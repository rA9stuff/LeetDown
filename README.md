# LeetDown
a GUI app to downgrade compatible A7 devices to iOS 10.3.3.

* Latest compiled version can be found [here](https://github.com/rA9stuff/LeetDown/releases).
* [Official LeetDown Twitter account](https://twitter.com/LeetDownApp) for updates & support. 
* [Official LeetDown webpage](https://LeetDown.app)

![alt text](https://i.imgur.com/JZDeZmf.png)


# If you are having issues with iPad restores, please use version 2.0.1 while I investigate the issue.




# Compatibility

LeetDown is compatible with the following A7 SoC devices:


* iPhone 5s
* iPad Mini 2
* iPad Air


LeetDown can run on following environments:

| Intel Macs    | Apple Silicon Macs |
| ------------- |:-------------:|
| macOS 10.13+   | macOS 11.0 - 11.2.3 |

# How to Use?

Mount the `LeetDown.dmg` and drag the `LeetDown.app` to your `/Applications` folder.

Follow the instructions shown in the app.

# F.A.Q.

Experimental Apple Silicon support: [As checkra1n team stated](https://checkra.in/news/2021/04/M1-announcement), Apple Silicon macs might have issues exploiting device or sending boot components. If you have problems with sending boot components, unplug your device after LeetDown sends iBSS, then plug it back in (LeetDown will wait for 5 seconds after sending each boot component to allow you to do this). If you have any other issues on Apple Silicon, feel free to open an issue.

# Having issues?

Sure, just open an issue using [LeetDown issue template](https://github.com/rA9stuff/LeetDown/issues/new/choose).

# Credits:

* [@axi0mX](https://twitter.com/axi0mX) for the legendary checkm8 exploit.

* [@tihmstar](https://twitter.com/tihmstar) for futurerestore.

* [@dora2ios](https://twitter.com/dora2ios) for "iPwnder32" which works amazingly well on A7 SoC.

* [@mosk_i](https://twitter.com/mosk_i) for boot component patches and notarizing the app (honestly can't thank him enough for this).

* [@libimobiledev](https://twitter.com/libimobiledev) for libirecovery.

* [@ConsoleLogLuke](https://twitter.com/ConsoleLogLuke) for helping with the dependencies and scripts :) (both are purposeless with the version 2.0 but I'll keep it here anyways for his help on the initial release).

* [ZipArchive](https://github.com/ZipArchive/ZipArchive) for SSZipArchive. 

* [AFNetworking](https://github.com/AFNetworking/AFNetworking) for AFNetworking.

* [@alitek123](https://twitter.com/alitek123) for modified BuildManifests. 
