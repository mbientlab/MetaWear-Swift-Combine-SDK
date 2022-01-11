// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

open class MWCloudKeyValueDataLoader<Loadable: VersionedContainerLoadable>: MWLoader<Loadable> {

    private let _loaded = PassthroughSubject<Loadable,Never>()

    private let key: String
    private unowned let local: UserDefaults
    private unowned let cloud: NSUbiquitousKeyValueStore

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var didRegisterObserver = false

    public init(key: String,
                _ local: UserDefaults,
                _ cloud: NSUbiquitousKeyValueStore) {
        self.key = key
        self.local = local
        self.cloud = cloud
        super.init(loaded: _loaded.eraseToAnyPublisher())
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc internal func cloudDidChange(_ note: Notification) {
        guard note.cloudDidChange(for: key) else { return }
        guard let data = cloud.data(forKey: key) else { return }
        do {
            let loadable = try Loadable.Container(data: data, decoder: decoder).load(decoder)
            _loaded.send(loadable)
        } catch { NSLog("\(Self.self) \(Loadable.self) \(error.localizedDescription)") }
    }

    public override func load() throws {
        if didRegisterObserver == false {
            didRegisterObserver = true
            NotificationCenter.default.addObserver(self, selector: #selector(cloudDidChange), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud)
        }
        let data = cloud.data(forKey: key) ?? local.data(forKey: key) ?? Data()
        let loadable = try Loadable.Container(data: data, decoder: decoder).load(decoder)
        _loaded.send(loadable)
    }

    public override func save(_ loadable: Loadable) throws {
        let data = try Loadable.Container.encode(loadable, encoder)
        local.set(data, forKey: key)
        cloud.set(data, forKey: key)
    }
}

public extension Notification {
    func cloudDidChange(for key: String) -> Bool {
        let key = NSUbiquitousKeyValueStoreChangedKeysKey
        let changes = (userInfo?[key] as? [NSString]) ?? []
        return changes.contains(.init(string: key))
    }
}
