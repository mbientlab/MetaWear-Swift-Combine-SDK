import Foundation
import MetaWear
import MetaWearSync

class Root {

    let syncedDevices: MetaWearSyncStore
    let scanner: MetaWearScanner

    private let localDefaults: UserDefaults
    private let cloudDefaults: NSUbiquitousKeyValueStore
    private let deviceLoader: MWLoader<MWKnownDevicesLoadable>

    init() {
        self.scanner = .sharedRestore
        self.localDefaults = .standard
        self.cloudDefaults = .default
        self.deviceLoader = MetaWeariCloudSyncLoader(localDefaults, cloudDefaults)
        self.syncedDevices = .init(scanner: scanner, loader: deviceLoader)
    }

    func start() {
        do {
            try syncedDevices.load()

        } catch { NSLog("Load failure: \(error.localizedDescription)") }
    }
}
