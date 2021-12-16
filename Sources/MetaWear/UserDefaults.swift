// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import CoreBluetooth
import Metal

public extension UserDefaults {

    struct MetaWear {

        /// Suite in which MetaWear will store devices
        public static var suite = UserDefaults.standard

        public struct Keys {

            /// Key that MetaWear uses to store a dictionary
            /// of local devices' CBUUIDs and MAC addresses
            public static let localPeripherals = "com.mbientlab.localPeripherals"

            /// Key that the `MetaWearMetadata` module uses to store
            /// Data for additional device metadata synced via iCloud
            public static let syncedMetadata = "com.mbientlab.syncedMetadata"
        }
    }
}

// MARK: - Local Peripherals Storage

public extension UserDefaults.MetaWear {

    /// Load devices recognized locally
    static func loadLocalDevices() -> [CBPeripheralIdentifier : MACAddress] {
        let stored = suite.dictionary(forKey: UserDefaults.MetaWear.Keys.localPeripherals) ?? [:]
        return stored.asPeripheralID_MACAddressDictionary()
    }

    /// Add device to local memory
    static func rememberLocalDevice(_ id: CBPeripheralIdentifier, _ mac: MACAddress) {
        var stored = loadLocalDevices_StringKeys()
        stored[id.uuidString] = mac
        save(devices: stored)
    }

    /// Remove device from local memory
    static func forgetLocalDevice(_ id: CBPeripheralIdentifier) {
        var stored = loadLocalDevices_StringKeys()
        stored.removeValue(forKey: id.uuidString)
        save(devices: stored)
    }

    /// Call once to migrate prior CBUUID and MAC storage keys (Bolts SDK) to this SDK.
    /// Retains any devices already in the new SDK (does not overwrite).
    ///
    static func migrateFromPriorSDK() {
        let oldSDKExisting = loadAndRemovePriorSDK()
        let newSDKExisting = loadLocalDevices()
        let merged = newSDKExisting.merging(oldSDKExisting) { newSDK, _ in newSDK }
        save(devices: merged)
    }

    /// Get the MAC address stored for a local CBPeripheral UUID
    static func getMAC(for id: CBPeripheralIdentifier) -> MACAddress? {
        loadLocalDevices()[id]
    }

}

// MARK: - Helpers

fileprivate func loadAndRemovePriorSDK() -> [CBPeripheralIdentifier:MACAddress] {
    UserDefaults.standard.removeObject(forKey: "com.mbientlab.rememberedDevices")

    let keyPrefix = "com.mbientlab.macstorage."
    let keyPrefixLength = keyPrefix.count
    let devices = UserDefaults.standard.dictionaryRepresentation()
        .reduce(into: [CBPeripheralIdentifier:MACAddress]()) { dict, element in
            guard element.key.hasPrefix(keyPrefix) else { return }
            print("//////////////", element)
            let uuidString = element.key.dropFirst(keyPrefixLength)
            UserDefaults.standard.removeObject(forKey: element.key)
            guard let uuid = UUID(uuidString: String(uuidString)),
                  let mac = element.value as? String
            else { return }
            dict[uuid] = mac
        }

    return devices
}

fileprivate func loadLocalDevices_StringKeys() -> [CBPeripheralIdentifier.UUIDString : MACAddress] {
    UserDefaults.MetaWear.suite
        .dictionary(forKey: UserDefaults.MetaWear.Keys.localPeripherals)?
        .compactMapValues { $0 as? MACAddress }
    ?? [:]
}

fileprivate func save(devices: [CBPeripheralIdentifier.UUIDString : MACAddress]) {
    UserDefaults.MetaWear.suite.set(devices, forKey: UserDefaults.MetaWear.Keys.localPeripherals)
}

fileprivate func save(devices: [CBPeripheralIdentifier : MACAddress]) {
    let stringKeys = devices.reduce(into: [CBPeripheralIdentifier.UUIDString : MACAddress]()) { dict, element in
        dict[element.key.uuidString] = element.value
    }
    UserDefaults.MetaWear.suite.set(stringKeys, forKey: UserDefaults.MetaWear.Keys.localPeripherals)
}

fileprivate extension Dictionary where Key == CBPeripheralIdentifier.UUIDString, Value == Any {

    func asPeripheralID_MACAddressDictionary() -> [CBPeripheralIdentifier : MACAddress] {
        reduce(into: [CBPeripheralIdentifier:MACAddress]()) { dict, element in
            guard let id = UUID(uuidString: element.key),
                  let mac = element.value as? String
            else { return }
            dict[id] = mac
        }
    }
}
