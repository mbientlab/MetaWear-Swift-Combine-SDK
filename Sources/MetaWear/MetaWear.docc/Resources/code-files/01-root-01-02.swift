import Foundation

class Root: ObservableObject {

    private let localDefaults: UserDefaults
    private let cloudDefaults: NSUbiquitousKeyValueStore

    init() {
        self.localDefaults = .standard
        self.cloudDefaults = .default
    }

    func start() {
        _ = cloudDefaults.synchronize()
    }
}
