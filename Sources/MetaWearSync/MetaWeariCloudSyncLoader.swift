// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

// MARK: - Basic iCloud key value storage implementation of MWKnownDevicesPersistence

/// Using local and cloud stores that you inject,
/// this saves and listens for shared MetaWear metadata updates.
///
/// You must call `cloud.synchronize()` after instantiating this object
/// for iCloud data sharing to work.
///
public class MetaWeariCloudSyncLoader: MWCloudKeyValueDataLoader<MWKnownDevicesLoadable> {

    public init(_ local: UserDefaults,
                _ cloud: NSUbiquitousKeyValueStore) {
        let key = UserDefaults.MetaWear.Keys.syncedMetadata
        super.init(key: key, local, cloud)
    }

    public static let sharedDefault = MetaWeariCloudSyncLoader(.standard, .default)
}
