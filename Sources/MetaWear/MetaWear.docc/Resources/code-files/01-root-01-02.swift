import Foundation
import MetaWear

class Root {

    let scanner: MetaWearScanner

    init() {
        self.scanner = .sharedRestore
    }

    func start() {

    }
}
