// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

public extension MetaWear {

    struct Group: Identifiable {
        public let id: UUID
        public var deviceMACs: Set<String>
        public var name: String

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
