// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

// MARK: - Basic iCloud key value storage implementation of MWKnownDevicesPersistence

/// Using local and cloud stores that you instantiate and manage elsewhere,
/// this saves and listens for shared MetaWear metadata updates.
///
/// You must call `cloud.synchronize()` after instantiating this object
/// for iCloud data sharing to work.
///
public class MWCloudLoader: MWKnownDevicesPersistence {

    public let metawears: AnyPublisher<MWKnownDevicesLoadable, Never>
    private unowned let local: UserDefaults
    private unowned let cloud: NSUbiquitousKeyValueStore

    private let key = UserDefaults.MetaWear.Keys.syncedMetadata
    private let _loadable = PassthroughSubject<MWKnownDevicesLoadable, Never>()

    public init(local: UserDefaults = UserDefaults.MetaWear.suite,
                cloud: NSUbiquitousKeyValueStore) {
        self.local = local
        self.cloud = cloud
        self.metawears = _loadable.eraseToAnyPublisher()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

extension MWCloudLoader {

    public func load() throws {
        guard let data = local.data(forKey: key) else { return }
        let loadable = try MWMetadataSaveContainer.decode(loadable: data)
        _loadable.send(loadable)
    }

    public func save(_ loadable: MWKnownDevicesLoadable) throws {
        let data = try MWMetadataSaveContainer.encode(metadata: loadable)
        local.set(data, forKey: key)
        cloud.set(data, forKey: key)
    }

    /// When iCloud synchronizes defaults at app startup, this function may be called.
    ///
    @objc internal func cloudDidChange(_ note: Notification) {
        guard let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [NSString] else { return }
        if changedKeys.contains(.init(string: key)),
           let data = cloud.data(forKey: key){
            do {
                let loadable = try MWMetadataSaveContainer.decode(loadable: data)
                _loadable.send(loadable)
            } catch { NSLog("MetaWear Metadata Cloud Decoding Failed: \(error.localizedDescription)") }
        }
    }
}
