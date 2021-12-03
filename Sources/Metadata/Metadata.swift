// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

public typealias CBPeripheralIdentifierUUIDString = String
public typealias MWMACAddress                     = String

public extension MetaWear {

    struct Metadata: Identifiable {
        /// Identified by MAC address
        public var id: String { mac }
        public var mac: MWMACAddress
        public var serial: String
        public var model: Model
        public var modules: Set<MWModules>

        public var localBluetoothIds: Set<CBPeripheralIdentifier>
        public var name: String

        public init(mac: String,
                    serial: String,
                    model: String,
                    modules: Set<MWModules>,
                    localBluetoothIds: Set<CBPeripheralIdentifier>,
                    name: String) {
            self.localBluetoothIds = localBluetoothIds
            self.mac = mac
            self.serial = serial
            self.model = .init(string: model)
            self.modules = modules
            self.name = name
        }

        public init(mac: String,
                    serial: String,
                    model: Model,
                    modules: Set<MWModules>,
                    localBluetoothIds: Set<CBPeripheralIdentifier>,
                    name: String) {
            self.localBluetoothIds = localBluetoothIds
            self.mac = mac
            self.serial = serial
            self.model = model
            self.modules = modules
            self.name = name
        }
    }
}

// MARK: - Utilities

extension MetaWear.Metadata: Comparable {
    public static func < (lhs: MetaWear.Metadata, rhs: MetaWear.Metadata) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
