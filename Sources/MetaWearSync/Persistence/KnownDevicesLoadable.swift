// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

/// Container for metadata for MetaWear devices and groups.
///
public struct MWKnownDevicesLoadable {
    public var groups: [MetaWear.Group]
    public var devices: [MetaWear.Metadata]

    public init(groups: [MetaWear.Group], devices: [MetaWear.Metadata]) {
        self.groups = groups
        self.devices = devices
    }
}

/// Versioning container for persistence
///
extension MWKnownDevicesLoadable: VersionedContainerLoadable {
   public typealias Container = MWKnownDevicesContainer
}
