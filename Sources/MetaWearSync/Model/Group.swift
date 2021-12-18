// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

public extension MetaWear {

    /// Grouping of MetaWears identified by MAC address.
    ///
    /// - Warning: Do not depend on `Codable` conformance for persistence.
    ///            Use for in-memory drag and drop only.
    ///
    struct Group: Identifiable, Codable {

        /// Group's unique ID, unrelated to CoreBluetooth
        public let id: UUID
        public var deviceMACs: Set<String>
        public var name: String

        /// Grouping of MetaWears identified by MAC address.
        ///
        public init(id: UUID,
                    deviceMACs: Set<String>,
                    name: String) {
            self.id = id
            self.deviceMACs = deviceMACs
            self.name = name
        }
    }
}

// MARK: - Utilities

extension MetaWear.Group: Comparable {
    public static func < (lhs: MetaWear.Group, rhs: MetaWear.Group) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

public extension Array where Element == MetaWear.Group {
    func allDevicesMACAddresses() -> Set<String> {
        reduce(into: Set<String>()) { $0.formUnion($1.deviceMACs) }
    }
}

extension UUID: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
