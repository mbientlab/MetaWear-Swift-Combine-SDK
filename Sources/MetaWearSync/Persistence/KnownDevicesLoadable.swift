// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

/// Container for metadata for MetaWear devices and groups.
///
public struct MWKnownDevicesLoadable {
    public var devices: [MetaWearMetadata]
    public var groups: [MetaWearGroup]
    public var groupsRecovery: [MetaWearGroup]

    public init(devices: [MetaWearMetadata], groups: [MetaWearGroup], groupsRecovery: [MetaWearGroup]) {
        self.devices = devices
        self.groups = groups
        self.groupsRecovery = groupsRecovery
    }

    public init() {
        self.groups = []
        self.devices = []
        self.groupsRecovery = []
    }
}

/// Versioning container for persistence
///
extension MWKnownDevicesLoadable: VersionedContainerLoadable {
   public typealias Container = MWKnownDevicesContainer
}
