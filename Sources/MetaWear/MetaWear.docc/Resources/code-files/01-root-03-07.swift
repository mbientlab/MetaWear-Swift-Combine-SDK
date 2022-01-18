import SwiftUI
import MetaWear
import Combine

class DiscoveredDeviceRowVM: ObservableObject {

    @Published var name: String
    @Published var rssi: String

    private unowned let device: MetaWear
    private var rssiSub: AnyCancellable? = nil

    init(device: MetaWear) {
        self.name = device.name
        self.device = device
        self.rssi = "-100"
    }

    func start() {
        self.rssiSub = device.rssiPublisher
            .receive(on: DispatchQueue.main)
            .map(String.init)
            .sink { [weak self] rssiString in
                self?.rssi = rssiString
            }
    }
}

struct DiscoveredDeviceRow: View {
    @StateObject var vm: DiscoveredDeviceRowVM

    var body: some View {
        NavigationLink(label, destination: Color.blue)
    }

    var label: some View {
        HStack {
            Text(vm.name)
                .bold()
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
