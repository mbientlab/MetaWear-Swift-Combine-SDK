import Foundation
import MetaWear

class Root: ObservableObject {

    let scanner: MetaWearScanner

    init() {
        self.scanner = .sharedRestore
    }

    func start() {

    }
}
