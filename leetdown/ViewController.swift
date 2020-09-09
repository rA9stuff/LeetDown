//
//  ViewController.swift
//  leetdown
//
//  Created by rA9 on 26.08.2020.
//  Copyright © 2020 rA9. All rights reserved.
//
// TODO:
// Fix dependencies / done
// Fix futurerestore (kill) / done
// breakpoint at custom ipsw creation / not needed



import Foundation
import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var leet: NSTextField!
   

    override func viewDidLoad() {
        super.viewDidLoad()
        
       
        
        
        }
        
        func runCommand(_ command: String, withAdmin: Bool = false) {
            NSAppleScript(source: "do shell script \"\(command)\" \(withAdmin ? "with administrator privileges" : "")")?
                    .executeAndReturnError(nil)
        }
    
    @IBAction func killbinaries(_ sender: Any) {
        runCommand("killall futurerestore")
        runCommand("killall pwnedDFU")
        runCommand("killall python")
        runCommand("killall zip")
        runCommand("killall unzip")
        runCommand("killall irecovery")
        runCommand("killall tsschecker")
        self.downgradebutton.isEnabled = false
        self.ipswselectiontext.isEnabled = true
        self.spinner.stopAnimation(.none)
        self.spinner.isHidden = true
        self.ph.stringValue = "Waiting for input"
        return
    }
    @IBOutlet weak var spinner: NSProgressIndicator!
    @IBOutlet weak var ipswselectiontext: NSButton!
    @IBOutlet weak var madeby: NSTextField!
    @IBOutlet weak var ph: NSTextField!
    @IBOutlet weak var downgradebutton: NSButton!
    @IBAction func ipsw(_ sender: Any) {
        
runCommand("killall futureresstore")
runCommand("killall pwnedDFU")
runCommand("killall python")
runCommand("killall zip")
runCommand("killall unzip")
runCommand("killall irecovery")
runCommand("killall tsschecker")
    
    self.ph.stringValue = "Triggering xcode cli tools installation prompt"
    self.spinner.startAnimation(.none)
    self.spinner.isHidden = false
            self.runCommand("git")
    // the oldest trick in the book
            self.runCommand("/Applications/leetdown.app/Contents/rsr/cleanup.sh")
    
        
        
        self.ph.stringValue = "Checking connected device"
        
            Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/query_device.sh"]).waitUntilExit()
        let f = FileManager.default
        if f.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/no_device") {
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
            self.ph.stringValue = "No device connected"
            return }
        else {
            
                self.runCommand("/Applications/leetdown.app/Contents/rsr/identify.sh")
        let fileManager = FileManager.default
                           if fileManager.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/supported") {
        self.spinner.stopAnimation(.none)
        self.spinner.isHidden = true
        

        
       
            self.ph.stringValue = "Connected device is compatible"
         
            
                
            
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
                    let path = result!.path
                    
                    
                    self.spinner.startAnimation(.none)
                       self.spinner.isHidden = false
                        self.ph.stringValue = "Copying the selected iPSW from " + path
                    DispatchQueue.global(qos: .background).async {
                        Process.launchedProcess(launchPath: "/bin/cp", arguments: ["\(path)", "/Applications/leetdown.app/Contents/rsr/"]).waitUntilExit()
                        self.runCommand("/Applications/leetdown.app/Contents/rsr/identify.sh")
                       if FileManager.default.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/no_ipsw") {
                        
                        DispatchQueue.main.async {
                        self.ph.stringValue = "ERROR: iPSW couldn't be copied"
                        self.downgradebutton.isEnabled = false
                        self.spinner.stopAnimation(.none)
                           self.spinner.isHidden = true
                        
                        } } else {
                        DispatchQueue.main.async {
                            self.ph.stringValue = "Successfully copied the iPSW"
                            self.downgradebutton.isEnabled = true
                            self.spinner.stopAnimation(.none)
                               self.spinner.isHidden = true
                        } } } }
            
            
                
            else {
                self.downgradebutton.isEnabled = false
                return
                            }
                            } }
          
        
    
                            else {
                            self.spinner.stopAnimation(.none)
                            self.spinner.isHidden = true
                            self.ph.stringValue = "Unsupported device"
                            return
                            
                            } } } 
    @IBAction func downgrade(_ sender: Any) {
        
        runCommand("killall futureresstore")
        runCommand("killall pwnedDFU")
        runCommand("killall python")
        runCommand("killall zip")
        runCommand("killall unzip")
        runCommand("killall irecovery")
        runCommand("killall tsschecker")
        
        self.spinner.startAnimation(.none)
        self.spinner.isHidden = false
        
       func runCommand(_ command: String, withAdmin: Bool = false) {
               NSAppleScript(source: "do shell script \"\(command)\" \(withAdmin ? "with administrator privileges" : "")")?
                   .executeAndReturnError(nil)
       }
       
        self.ph.stringValue = "Cleaning up"
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/cleanupafterparty.sh"]).waitUntilExit()

        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/identify.sh"]).waitUntilExit()
      
        if FileManager.default.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/supported") {
             
                self.ph.stringValue = "Checking connected device status"
    
       Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/query_device.sh"]).waitUntilExit()
                            
                            
       let filea = FileManager.default
       if filea.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/no_device") {
        
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
            self.ph.stringValue = "No device connected"
        return }
         else {
       
       let fileManager = FileManager.default
                          if fileManager.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/no_dfu") {
                            DispatchQueue.main.async {
                            self.ph.stringValue = "Please connect your device in DFU mode"
                                self.spinner.stopAnimation(.none)
                                self.spinner.isHidden = true
                            }
                            return }
                            else {
         
                            
                                self.ph.stringValue = "Checking dependencies"
                            Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/dependency_check.sh"]).waitUntilExit()
                            
                            
                            let file = FileManager.default
                                                       if file.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/libusb_missing") {
                                                        
                                       
                    
                                        self.spinner.stopAnimation(.none)
                                        self.spinner.isHidden = true
                                        
                                       let a = NSAlert()
                                                                   
                                               a.messageText = "Libusb missing"
                                               a.informativeText = "You need to have libusb installed in order to run this tool."
                                       //            .alertFirstButtonReturn
                                              a.addButton(withTitle: "Install")

                                       //          .alertSecondButtonReturn
                                               a.addButton(withTitle: "Cancel")
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
                                                    self.downgradebutton.isEnabled = false
                                                      self.ipswselectiontext.isEnabled = false
                                                      self.ph.stringValue = "Installing dependencies"
                                                      self.spinner.startAnimation(.none)
                                                      self.spinner.isHidden = false
                                                      
                                                      DispatchQueue.global(qos: .background).async {
                                                      
                                                      runCommand("/Applications/leetdown.app/Contents/rsr/dependency_install.sh", withAdmin: true)
                                                    
                                                         runCommand("/Applications/leetdown.app/Contents/rsr/dependency_check.sh")
                                                          
                                                      let file = FileManager.default
                                                      if file.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/libusb_missing") {
                                                           DispatchQueue.main.async {
                                                              self.spinner.stopAnimation(.none)
                                                              self.spinner.isHidden = true
                                                              self.ph.stringValue = "Failed to install libusb" } } else {
                                                          DispatchQueue.main.async {
                                                              self.spinner.stopAnimation(.none)
                                                              self.spinner.isHidden = true
                                                              self.ph.stringValue = "Successfully installed libusb"
                                                        self.downgradebutton.isEnabled = true
                                                            self.ipswselectiontext.isEnabled = true }
                                                      
                                                          
                                                      
                                                          } } } } }
                                                          
                                                      return
                                                          } else {
                                                    
                                                                    
                                                        
       let a = NSAlert()
                            
        a.messageText = "Warning"
        a.informativeText = "Restoring will delete everything from your device. Are you sure you want to continue?"
//            .alertFirstButtonReturn
       a.addButton(withTitle: "Continue")

//          .alertSecondButtonReturn
        a.addButton(withTitle: "Cancel")
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
            
            let a = NSAlert()
                                        
                    a.messageText = "Exploit Selection"
                    a.informativeText = "Please choose which checkm8 binary you want to use to exploit your device. \"pwnedDFU\" works reliable with newer macs, but if you have an older model like 2010/2011, you may want to select \"ipwndfu\""
            //            .alertFirstButtonReturn
                   a.addButton(withTitle: "pwnedDFU")

            //          .alertSecondButtonReturn
                    a.addButton(withTitle: "ipwndfu")
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
                            
       DispatchQueue.global(qos: .background).async {
        
        DispatchQueue.main.async {
            
            self.ipswselectiontext.isEnabled = false
            self.downgradebutton.isEnabled = false
            self.spinner.startAnimation(.none)
            self.spinner.isHidden = false
            
        self.ph.stringValue = "Exploiting using pwnedDFU binary" }
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/pwnedDFU.sh"]).waitUntilExit()
       
              let ffileManager = FileManager.default
                    if ffileManager.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/failed") {
                        DispatchQueue.main.async {
                      let a = NSAlert()
                            self.ipswselectiontext.isEnabled = true
                            self.downgradebutton.isEnabled = true
                      a.messageText = "Exploit failed"
                      a.informativeText = "Failed to enter pwnedDFU. Please re-enter DFU mode and click the downgrade button to try again."
                      //   .alertFirstButtonReturn
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
                  self.ph.stringValue = "Failed to enter pwnedDFU"
                            self.spinner.stopAnimation(.none)
                            self.spinner.isHidden = true
                            return
                            } } } } } else {
    DispatchQueue.main.async {
        self.ph.stringValue = "Verifying iPSW"
        self.downgradebutton.isEnabled = false
        self.ipswselectiontext.isEnabled = false }
                        
                        if FileManager.default.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/ipsw_create_err") {
                            Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/cleanup.sh"]).waitUntilExit()
                            DispatchQueue.main.async {
                         self.ph.stringValue = "iPSW couldn't be created, make sure you have enough space"
                         self.downgradebutton.isEnabled = false
                         self.ipswselectiontext.isEnabled = true
                                return } } else {
                                
                                
              DispatchQueue.main.async {
                self.downgradebutton.isEnabled = false
                self.ipswselectiontext.isEnabled = false
                self.ph.stringValue = "Saving SHSH..." }
                        
                        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/shsh.sh"]).waitUntilExit()
                        
                        
   DispatchQueue.main.async {
    self.ph.stringValue = "Creating custom iPSW, this might take a while..." }
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/prep.sh"]).waitUntilExit()
                        
                        
     DispatchQueue.main.async {
        self.ph.stringValue = "Restoring device, do NOT close the app!" }
        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/down.sh"]).waitUntilExit()
                        
                         DispatchQueue.main.async {
                            self.ph.stringValue = "Cleaning up..." }
                        
                        Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/cleanup.sh"]).waitUntilExit()
                        let fileManager = FileManager.default
                           if fileManager.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/restore_failed") {
                               DispatchQueue.main.async {
                                self.spinner.stopAnimation(.none)
                                self.spinner.isHidden = true
                                   self.ph.stringValue = "Restore failed. Press the killswitch to try again"
                            self.ipswselectiontext.isEnabled = false
                            self.downgradebutton.isEnabled = false
                            } } else {
                            
                    DispatchQueue.main.async {
                        self.spinner.stopAnimation(.none)
                        self.spinner.isHidden = true
                        self.ph.stringValue = "Complete! Please report any issues to @rA9_baris"
                self.ipswselectiontext.isEnabled = true
                        self.downgradebutton.isEnabled = false }
                    
    
                            } } } } } else {
                        DispatchQueue.global(qos: .background).async {
                            
                            
                            
                             let yol = "/bin/bash"
                             let arg = ["/Applications/leetdown.app/Contents/rsr/ipwndfu.sh"]
                             let tas = Process.launchedProcess(launchPath: yol, arguments: arg)
                                 DispatchQueue.main.async {
                                    self.spinner.startAnimation(.none)
                                    self.spinner.isHidden = false
                                     self.ph.stringValue = "Exploiting using ipwndfu binary"
                            self.downgradebutton.isEnabled = false
                                    self.ipswselectiontext.isEnabled = false }
                                 tas.waitUntilExit()
                                                 
                                     
                            
                                   let ffileManager = FileManager.default
                                         if ffileManager.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/failed") {
                                             DispatchQueue.main.async {
                                           let a = NSAlert()
                                                self.spinner.stopAnimation(.none)
                                                self.spinner.isHidden = true
                                           a.messageText = "Error"
                                           a.informativeText = "Failed to enter pwnedDFU. Please re-enter DFU mode and click the downgrade button to try again."
                                           //   .alertFirstButtonReturn
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
                                       self.ph.stringValue = "Failed to enter pwnedDFU"
                                                 } } } } } else {
                                            
                                   DispatchQueue.main.async {
                                    self.downgradebutton.isEnabled = false
                                    self.ipswselectiontext.isEnabled = false
                                     self.ph.stringValue = "Saving SHSH..." }
                            Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/shsh.sh"]).waitUntilExit()
                        DispatchQueue.main.async {
                         self.ph.stringValue = "Creating custom iPSW, this might take a while..." }
                             Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/prep.sh"]).waitUntilExit()
 
                          DispatchQueue.main.async {
                             self.ph.stringValue = "Restoring device, do NOT close the app!" }
                             Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/down.sh"]).waitUntilExit()
                                                
                                              DispatchQueue.main.async {
                                                 self.ph.stringValue = "Cleaning up..." }
                                         Process.launchedProcess(launchPath: "/bin/bash", arguments: ["/Applications/leetdown.app/Contents/rsr/cleanup.sh"]).waitUntilExit()
                                      
                                            
                                            let fileManager = FileManager.default
                                            if fileManager.fileExists(atPath: "/Applications/leetdown.app/Contents/rsr/restore_failed") {
                                                DispatchQueue.main.async {
                                                    self.spinner.stopAnimation(.none)
                                                    self.spinner.isHidden = true
                                                    self.ph.stringValue = "Restore failed. Press the killswitch to try again"
                                                self.downgradebutton.isEnabled = false
                                                    self.ipswselectiontext.isEnabled = false }
                                            
                                            } else {
                                         DispatchQueue.main.async {
                                            self.spinner.stopAnimation(.none)
                                            self.spinner.isHidden = true
                                             self.ph.stringValue = "Complete! Please report any issues to @rA9_baris"
                                     self.ipswselectiontext.isEnabled = true
                                             self.downgradebutton.isEnabled = false }
                        
                        
                                            } } } }
                  
                            return } } } else {
            self.downgradebutton.isEnabled = true
            self.ipswselectiontext.isEnabled = true
            self.ph.stringValue = "Waiting for input"
            self.spinner.stopAnimation(.none)
            self.spinner.isHidden = true
                
                } } } } } } }   else {
                                            DispatchQueue.main.async {
                                                self.spinner.stopAnimation(.none)
                                                self.spinner.isHidden = true
                                                self.ph.stringValue = "Unsupported device" } } }
                            
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
