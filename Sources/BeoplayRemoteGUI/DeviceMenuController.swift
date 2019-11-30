//
//  DeviceMenuController.swift
//  BeoplayRemoteGUI
//
//  Created by Thomas L. Kjeldsen on 25/11/2019.
//

import Cocoa

class DeviceMenuController : NSObject, NetServiceDelegate {
    private let q = DispatchQueue.main
    private let statusMenuController: StatusMenuController
    private let statusMenu: NSMenu

    public init(_ statusMenuController: StatusMenuController) {
        self.statusMenuController = statusMenuController
        self.statusMenu = statusMenuController.statusMenu
    }

    public func selectDeviceMenuItem(_ selectedItem: NSMenuItem) {
        self.q.async {
            let items = self.getDeviceMenuItems()
            for item in self.getSelected(items) {
                item.state = NSControl.StateValue.off
            }

            selectedItem.state = NSControl.StateValue.on
        }
    }

    public func handleDeviceUpdates(_ updates: [DeviceCommand]) {
        self.q.async {
            
            for update in updates {
                let menuHasDevice = self.statusMenu.indexOfItem(withRepresentedObject: update.device) > -1
            
                switch update.type {
                case DeviceAction.Add:
                    if menuHasDevice == false {
                        self.addDevice(update.device)
                    }
                case DeviceAction.Remove:
                    self.removeDevice(update.device)
                }
            }
        }
    }
    
    func didUpdateDevices() {
        let menuItems = self
            .getDeviceMenuItems()
            .filter { $0.isEnabled }
        
        switch menuItems.count {
        case 0:
            NSLog("no devices available")
        default:
            guard let defaultDevice = UserDefaults.standard.string(forKey: "devices.default") else {
                return
            }
            
            if self.getSelected(menuItems).count == 0 {
                if let item = menuItems.filter({ $0.title == defaultDevice }).first {
                    NSLog("connecting to default device")
                    self.statusMenuController.connectDevice(item)

                }
            }
        }
    }

    func removeDevice(_ device: NetService) {
        NSLog("removeDevice: \(device.name)")
        
        if let item = self.getMenuItem(device) {
            self.statusMenu.removeItem(item)
            self.didUpdateDevices()
        }
    }

    func addDevice(_ device: NetService) {
        NSLog("addDevice: \(device.name)")
    
        let target = self.statusMenuController
        let item = NSMenuItem(title: device.name, action: #selector(target.deviceClicked(_:)), keyEquivalent: "")
        item.representedObject = device
        item.target = target
        item.isEnabled = false
        
        self.statusMenu.insertItem(item, at: self.getLocationForNew(item))

        // The menu item is enabled by the delegate when the service address has been resolved
        device.delegate = self
        device.resolve(withTimeout: TimeInterval(5.0))
    }

    func netServiceDidResolveAddress(_ service: NetService) {
        NSLog("netServiceDidResolveAddress: \(service.hostName!)")
        
        let menuItem = self.getMenuItem(service)
        
        menuItem?.isEnabled = true
        self.didUpdateDevices()
    }

    private func getLocationForNew(_ newItem: NSMenuItem) -> Int {
        for item in getDeviceMenuItems() {
            if newItem.title < item.title {
                return statusMenu.index(of: item)
            }
        }
        return self.statusMenu.index(of: self.statusMenuController.deviceSeparatorMenuItem)
    }

    private func getDeviceMenuItems() -> [NSMenuItem] {
        self.statusMenu.items.filter { $0.representedObject is NetService }
    }

    private func getSelected(_ items: [NSMenuItem]) -> [NSMenuItem] {
        items.filter { $0.state == NSControl.StateValue.on }
    }
        
    private func getMenuItem(_ device: NetService) -> NSMenuItem? {
        let location = self.statusMenu.indexOfItem(withRepresentedObject: device)
        return self.statusMenu.item(at: location)
    }
    
}
