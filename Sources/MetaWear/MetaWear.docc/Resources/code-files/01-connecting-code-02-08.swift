import SwiftUI
import MetaWear
import Combine

class DiscoveredDeviceRowVM: ObservableObject {

    @Published var name: String

    private unowned let device: MetaWear

    init(device: MetaWear) {
        self.name = device.name
        self.device = device
    }
}
