//
//  ViewController.swift
//  leetdown
//
//  Created by rA9 on 26.08.2020.
//  Copyright © 2020 rA9. All rights reserved.
//

import Foundation
import Cocoa

class ViewController: NSViewController {
    
    var isBusy = false
    @IBOutlet weak var leet: NSTextField!
    @IBOutlet weak var statusbox: NSScrollView!
    @IBOutlet var statusLabel: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(self.refreshStatus), userInfo: nil, repeats: true)
        setStatus("[*] Waiting for input\n")
    
    }

@objc func refreshStatus() {
    if isBusy {
        self.statusLabel.scrollToEndOfDocument(self)
    }
}
    
func setStatus(_ status: String) {
    let font: NSFont
    if #available(macOS 10.15, *) {
        font = NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
    } else {
        font = NSFont.userFixedPitchFont(ofSize: 0)!
    }

    let attributedString = NSAttributedString(string: status, attributes: [
        .font: font,
        .foregroundColor: NSColor.green
    ])
        statusLabel.textStorage?.append(attributedString)
    }
        
func runCommand(_ command: String, withAdmin: Bool = false) {
    NSAppleScript(source: "do shell script \"\(command)\" \(withAdmin ? "with administrator privileges" : "")")?
        .executeAndReturnError(nil)
}
    
    
func killbinaries() {
    
    setStatus("[*] Killing Binaries\n")
    runCommand("killall futurerestore")
    runCommand("killall pwnedDFU")
    runCommand("killall python")
    runCommand("killall zip")
    runCommand("killall unzip")
    runCommand("killall irecovery")
    runCommand("killall tsschecker")
    self.downgradebutton.isEnabled = false
    self.ipswselectiontext.isEnabled = true
    self.spinner.startAnimation(.none)
    self.spinner.isHidden = false
    return
}
    
@IBOutlet weak var spinner: NSProgressIndicator!
@IBOutlet weak var ipswselectiontext: NSButton!
@IBOutlet weak var madeby: NSTextField!
@IBOutlet weak var downgradebutton: NSButton!
@IBAction func ipsw(_ sender: Any) {
     
    isBusy = true
    killbinaries()
 
    self.spinner.isHidden = false
    self.runCommand("git")
    self.setStatus("[*] Triggering Xcode CLI tools installation\n")
    self.runCommand("/Applications/LeetDown.app/Contents/rsr/cleanup.sh")
    self.setStatus("[*] Cleaning up\n")
    
    Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/query_device.sh"]).waitUntilExit()
    
    if FileManager.default.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/no_device") {
        self.setStatus("[*] No device detected\n")
        self.spinner.stopAnimation(.none)
        self.spinner.isHidden = true
        isBusy = false
        
    } else {
            
        self.runCommand("/Applications/LeetDown.app/Contents/rsr/identify.sh")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/supported") {
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
            self.setStatus("[*] Connected device is supported\n")
            
        let dialog = NSOpenPanel();
            
        dialog.title                   = "Choose an iPSW";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.canCreateDirectories    = false;
        dialog.allowsMultipleSelection = false;
        dialog.allowedFileTypes        = ["ipsw"];
            
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url
    
            if (result != nil) {
                isBusy = true
                let path = result!.path
                    
                self.spinner.startAnimation(.none)
                self.spinner.isHidden = false
                setStatus("[*] Copying the selected iPSW from " + path + "\n")
                
                    DispatchQueue.global(qos: .background).async {
                    Process.launchedProcess(launchPath: "/bin/cp", arguments: ["\(path)", "/Applications/LeetDown.app/Contents/rsr/"]).waitUntilExit()
                    self.runCommand("/Applications/LeetDown.app/Contents/rsr/identify.sh")
                    if FileManager.default.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/no_ipsw") {
                        
                    DispatchQueue.main.async {
                    self.setStatus("[*] ERROR: iPSW couldn't be copied\n")
                    self.downgradebutton.isEnabled = false
                    self.spinner.stopAnimation(.none)
                    self.spinner.isHidden = true
                    self.isBusy = false
                        
                    } } else {
                        DispatchQueue.main.async {
                        self.setStatus("[*] Successfully copied the iPSW\n")
                        self.downgradebutton.isEnabled = true
                        self.spinner.stopAnimation(.none)
                        self.spinner.isHidden = true
                        self.isBusy = false
                    } } }
                
            } else {
                self.setStatus("[*] ERROR: iPSW couldn't be selected\n")
                self.downgradebutton.isEnabled = false
                self.isBusy = false
            }
        } else {
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
            self.setStatus("[*] No iPSW were specified\n")
            self.isBusy = false
        }
        } else {
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
            self.setStatus("[*] Unsupported device\n")
            self.isBusy = false
            return
        } } }
    
@IBAction func downgrade(_ sender: Any) {
    isBusy = true
    killbinaries()
        
    self.spinner.startAnimation(.none)
    self.spinner.isHidden = false
    self.setStatus("[*] Cleaning up\n")
    
    Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/cleanupafterparty.sh"]).waitUntilExit()

    Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/identify.sh"]).waitUntilExit()
  
      
    if FileManager.default.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/supported") {
        self.setStatus("[*] Checking connected device status\n")
        
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/query_device.sh"]).waitUntilExit()
            
                            
    let filea = FileManager.default
    if filea.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/no_device") {
        isBusy = false
        self.spinner.stopAnimation(.none)
        self.spinner.isHidden = true
        setStatus("No device connected\n")
        return
    } else {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/no_dfu") {
            DispatchQueue.main.async {
                self.isBusy = false
            self.setStatus("[*] Device is connected with wrong mode, please put your device in DFU mode\n")
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
            }
            return
        } else {
            self.setStatus("[*] Checking dependencies\n")
            Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/dependency_check.sh"]).waitUntilExit()
            let file = FileManager.default
            if file.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/libusb_missing") {
                isBusy = false
                self.spinner.stopAnimation(.none)
                self.spinner.isHidden = true
                let a = NSAlert()
                a.messageText = "Libusb missing"
                a.informativeText = "You need to have libusb installed in order to run this tool."
                a.addButton(withTitle: "Install")
                a.addButton(withTitle: "Cancel")
                a.alertStyle = .warning
                var w: NSWindow?
                if let window = self.view.window {
                    w = window
                }
                else if let window = NSApplication.shared.windows.first {
                    w = window
                }
                if let window = w {
                    a.beginSheetModal(for: window){ (modalResponse) in
                    if modalResponse == .alertFirstButtonReturn {
                        self.isBusy = true
                        self.downgradebutton.isEnabled = false
                        self.ipswselectiontext.isEnabled = false
                        self.setStatus("[*] Installing dependencies\n")
                        self.spinner.startAnimation(.none)
                        self.spinner.isHidden = false
                                                
                        DispatchQueue.global(qos: .background).async {
                        self.runCommand("/Applications/LeetDown.app/Contents/rsr/dependency_install.sh", withAdmin: true)
                        self.runCommand("/Applications/LeetDown.app/Contents/rsr/dependency_check.sh")
                                                        
                        let file = FileManager.default
                        if file.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/libusb_missing") {
                            DispatchQueue.main.async {
                                self.isBusy = false
                                self.spinner.stopAnimation(.none)
                                self.spinner.isHidden = true
                                self.setStatus("[*] Failed to install libusb\n") }
                        } else {
                            DispatchQueue.main.async {
                            self.isBusy = false
                            self.spinner.stopAnimation(.none)
                            self.spinner.isHidden = true
                            self.setStatus("[*] Successfully installed libusb\n")
                            self.downgradebutton.isEnabled = true
                            self.ipswselectiontext.isEnabled = true }
                        }
                        }
                    }
                    }
                }
                return
    } else {
                                                            
        let a = NSAlert()
        a.messageText = "Warning"
        a.informativeText = "Restoring will delete everything from your device. Are you sure you want to continue?"
        a.addButton(withTitle: "Continue")
        a.addButton(withTitle: "Cancel")
        a.alertStyle = .warning
        var w: NSWindow?
        if let window = self.view.window {
            w = window
        }
        else if let window = NSApplication.shared.windows.first {
            w = window
        }
        if let window = w {
            a.beginSheetModal(for: window) { (modalResponse) in
            if modalResponse == .alertFirstButtonReturn {
            
                let a = NSAlert()
                a.messageText = "Exploit Selection"
                a.informativeText = "Please choose which checkm8 binary you want to use to exploit your device. \"pwnedDFU\" works reliable with newer macs, but if you have an older model like 2010/2011, you may want to select \"ipwndfu\""
                a.addButton(withTitle: "pwnedDFU")
                a.addButton(withTitle: "ipwndfu")
                a.alertStyle = .warning
                var w: NSWindow?
                if let window = self.view.window {
                    w = window
                }
                else if let window = NSApplication.shared.windows.first {
                    w = window
                }
                if let window = w {
                    a.beginSheetModal(for: window){ (modalResponse) in
                    if modalResponse == .alertFirstButtonReturn {
                            
        DispatchQueue.global(qos: .background).async {
        DispatchQueue.main.async {
        self.isBusy = true
        self.ipswselectiontext.isEnabled = false
        self.downgradebutton.isEnabled = false
        self.spinner.startAnimation(.none)
        self.spinner.isHidden = false
        self.setStatus("[*] Exploiting using pwnedDFU binary\n") }
            
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/pwnedDFU.sh"]).waitUntilExit()
        let ffileManager = FileManager.default
            if ffileManager.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/failed") {
                DispatchQueue.main.async {
                self.isBusy = false
                let a = NSAlert()
                self.ipswselectiontext.isEnabled = true
                self.downgradebutton.isEnabled = true
                a.messageText = "Exploit failed"
                a.informativeText = "Failed to enter pwnedDFU. Please re-enter DFU mode and click the downgrade button to try again."
                a.addButton(withTitle: "OK")
                a.alertStyle = .warning
                var w: NSWindow?
                if let window = self.view.window {
                    w = window
                }
                else if let window = NSApplication.shared.windows.first{
                    w = window
                }
                if let window = w {
                    a.beginSheetModal(for: window){ (modalResponse) in
                if modalResponse == .alertFirstButtonReturn {
                      
                    self.ipswselectiontext.isEnabled = true
                    self.downgradebutton.isEnabled = true
                    self.setStatus("[*] Failed to enter pwnedDFU\n")
                    self.spinner.stopAnimation(.none)
                    self.spinner.isHidden = true
                    return
                } } } }
            } else {
    DispatchQueue.main.async {
    self.isBusy = true
    self.setStatus("[*] Verifying iPSW\n")
    self.downgradebutton.isEnabled = false
    self.ipswselectiontext.isEnabled = false }
                        
    if FileManager.default.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/ipsw_create_err") {
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/cleanup.sh"]).waitUntilExit()
        DispatchQueue.main.async {
        self.isBusy = false
        self.setStatus("[*] iPSW couldn't be created, make sure you have enough space\n")
        self.downgradebutton.isEnabled = false
        self.ipswselectiontext.isEnabled = true
        self.spinner.stopAnimation(.none)
        self.spinner.isHidden = true
        return }
    } else {
        DispatchQueue.main.async {
        self.isBusy = true
        self.downgradebutton.isEnabled = false
        self.ipswselectiontext.isEnabled = false
        self.setStatus("[*] Saving 10.3.3 OTA SHSH\n") }
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/shsh.sh"]).waitUntilExit()
                        
   DispatchQueue.main.async {
   self.setStatus("[*] Creating custom iPSW, this might take a while\n") }
   Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/prep.sh"]).waitUntilExit()
        
   DispatchQueue.main.async {
   self.setStatus("[*] Restoring device\n") }
   Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/down.sh"]).waitUntilExit()
                        
   DispatchQueue.main.async {
   self.setStatus("[*] Cleaning up\n") }
                        
   Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/cleanup.sh"]).waitUntilExit()
   let fileManager = FileManager.default
   if fileManager.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/restore_failed") {
        DispatchQueue.main.async {
        self.isBusy = false
        self.spinner.stopAnimation(.none)
        self.spinner.isHidden = true
        self.setStatus("[*] Restore failed.\n")
        self.ipswselectiontext.isEnabled = false
        self.downgradebutton.isEnabled = false
        }
   } else {
        DispatchQueue.main.async {
        self.isBusy = false
        self.spinner.stopAnimation(.none)
        self.spinner.isHidden = true
        self.setStatus("[*] Complete! Please report any issues to @rA9_main\n")
        self.ipswselectiontext.isEnabled = true
        self.downgradebutton.isEnabled = false }
    } } } } } else {
        DispatchQueue.global(qos: .background).async {
                            
        let way = "/bin/bash"
        let arg = ["/Applications/LeetDown.app/Contents/rsr/ipwndfu.sh"]
        let tas = Process.launchedProcess(launchPath: way, arguments: arg)
        DispatchQueue.main.async {
        self.spinner.startAnimation(.none)
        self.spinner.isHidden = false
        self.setStatus("[*] Exploiting using ipwndfu binary\n")
        self.downgradebutton.isEnabled = false
        self.ipswselectiontext.isEnabled = false }
        tas.waitUntilExit()
            
        let ffileManager = FileManager.default
        if ffileManager.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/failed") {
            DispatchQueue.main.async {
            let a = NSAlert()
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
            a.messageText = "Error"
            a.informativeText = "Failed to enter pwnedDFU. Please re-enter DFU mode and click the downgrade button to try again."
            a.addButton(withTitle: "OK")
            a.alertStyle = .warning
            var w: NSWindow?
            if let window = self.view.window{
                w = window
            }
            else if let window = NSApplication.shared.windows.first{
                w = window
            }
            if let window = w{
                a.beginSheetModal(for: window){ (modalResponse) in
                if modalResponse == .alertFirstButtonReturn {
                                        
                    self.ipswselectiontext.isEnabled = true
                    self.downgradebutton.isEnabled = true
                    self.setStatus("[*] Failed to enter pwnedDFU\n")
                } } } } } else {
                                            
                    DispatchQueue.main.async {
                    self.downgradebutton.isEnabled = false
                    self.ipswselectiontext.isEnabled = false
                    self.setStatus("[*] Saving 10.3.3 OTA SHSH\n") }
                    Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/shsh.sh"]).waitUntilExit()
                    DispatchQueue.main.async {
                    self.setStatus("[*] Creating custom iPSW, this might take a while\n") }
                    Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/prep.sh"]).waitUntilExit()
 
                    DispatchQueue.main.async {
                             self.setStatus("[*] Restoring device\n") }
                             Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/down.sh"]).waitUntilExit()
                                                
                                              DispatchQueue.main.async {
                                                self.setStatus("[*] Cleaning up\n") }
                                         Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/LeetDown.app/Contents/rsr/cleanup.sh"]).waitUntilExit()
                                      
                                            
                                            let fileManager = FileManager.default
                                            if fileManager.fileExists(atPath: "/Applications/LeetDown.app/Contents/rsr/restore_failed") {
                                                DispatchQueue.main.async {
                                                    self.spinner.stopAnimation(.none)
                                                    self.spinner.isHidden = true
                                                    self.setStatus("[*] Restore failed\n")
                                                self.downgradebutton.isEnabled = false
                                                    self.ipswselectiontext.isEnabled = false }
                                            
                                            } else {
                                         DispatchQueue.main.async {
                                            self.spinner.stopAnimation(.none)
                                            self.spinner.isHidden = true
                                             self.setStatus("[*] Complete! Please report any issues to @rA9_main\n")
                                     self.ipswselectiontext.isEnabled = true
                                             self.downgradebutton.isEnabled = false }
                        
                        
                                            } } } }
                  
                            return } } } else {
                                self.isBusy = false
            self.downgradebutton.isEnabled = true
            self.ipswselectiontext.isEnabled = true
            self.setStatus("[*] Waiting for input\n")
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
                
                } } } } } } }   else {
                                            DispatchQueue.main.async {
                                                self.spinner.stopAnimation(.none)
                                                self.spinner.isHidden = true
                                                self.setStatus("[*] Unsupported device\n")
                                            } } }
                            
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
