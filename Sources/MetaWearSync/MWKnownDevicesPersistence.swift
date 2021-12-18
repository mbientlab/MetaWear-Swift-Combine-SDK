// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

/// Contract for saving and loading MetaWears for the ``MetaWearSyncStore``.
///
public protocol MWKnownDevicesPersistence: AnyObject {
    func load() throws
    func save(_ loadable: MWKnownDevicesLoadable) throws
    var metawears: AnyPublisher<MWKnownDevicesLoadable, Never> { get }
}


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
