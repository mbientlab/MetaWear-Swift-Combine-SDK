// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import CoreBluetooth

public extension UserDefaults {
    struct MetaWear { public struct Keys {
        public static let localPeripheralIDs = "MetaWearLocalPeripherals"
        public static let syncedMetadata = "MetaWearSyncedMetadata"
    } }
}

public extension UserDefaults.MetaWear {

    static func getMac(for metawear: MetaWear) -> String? {
        getMac(for: metawear.peripheral)
    }

    static func setMac(_ string: String, for metawear: MetaWear) {
        setMac(string, for: metawear.peripheral)
    }

}

public extension UserDefaults.MetaWear {

    static func getMac(for peripheral: CBPeripheral) -> String? {
        let key = Keys.macStorage(for: peripheral)
        return UserDefaults.standard.string(forKey: key)
    }

    static func setMac(_ string: String,for peripheral: CBPeripheral) {
        let key = Keys.macStorage(for: peripheral)
        UserDefaults.standard.set(string, forKey: key)
    }
}

// MARK: - MAC Address Storage

public extension UserDefaults.MetaWear.Keys {

    static func macStorage(for metawear: MetaWear) -> String {
        macStorage(for: metawear.peripheral)
    }

    static func macStorage(for peripheral: CBPeripheral) -> String {
        macStoragePrefix + peripheral.identifier.uuidString
    }

    static let macStoragePrefix = "com.mbientlab.macstorage."
}
