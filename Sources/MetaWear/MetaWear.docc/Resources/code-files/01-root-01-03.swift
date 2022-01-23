import Foundation
import MetaWear

class Root {

    let scanner: MetaWearScanner

    private let localDefaults: UserDefaults

    init() {
        self.scanner = .sharedRestore
        self.localDefaults = .standard
    }

    func start() {

    }
}
