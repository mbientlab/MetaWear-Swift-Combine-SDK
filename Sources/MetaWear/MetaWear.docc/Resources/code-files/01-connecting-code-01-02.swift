import SwiftUI
import MetaWear
import Combine

class DiscoveriesVM: ObservableObject {

    @Published var devices = [UUID]()

}

struct DiscoveredDevicesList: View {
    @StateObject private var vm: DiscoveriesVM = .init()

    var body: some View {
        List {
            ForEach(vm.devices, id: \.self) { id in

            }
        }
    }
}
