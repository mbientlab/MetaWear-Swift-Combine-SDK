import SwiftUI
import MetaWear
import Combine

class DiscoveriesVM: ObservableObject {

    @Published var devices = [UUID]()

    private var scan: AnyCancellable? = nil

    init(scanner: MetaWearScanner = .sharedRestore) {
        scan = scanner
            .didDiscoverUniqued
            .map(\.peripheral.identifier)
    }
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
