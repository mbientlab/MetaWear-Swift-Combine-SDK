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
