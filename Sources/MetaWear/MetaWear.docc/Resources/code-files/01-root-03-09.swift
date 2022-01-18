import SwiftUI
import MetaWear
import Combine

class DiscoveriesVM: ObservableObject {

    @Published var devices = [UUID]()

    private var scan: AnyCancellable? = nil
    private unowned let scanner: MetaWearScanner

    init(scanner: MetaWearScanner = .sharedRestore) {
        self.scanner = scanner
        scan = scanner
            .didDiscoverUniqued
            .map(\.peripheral.identifier)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceID in
                self?.devices.append(deviceID)
            }
    }

    func start() {
        scanner.startScan(allowDuplicates: false)
    }

    func stop() {
        scanner.stopScan()
    }

    func makeRowVM(for id: UUID) -> DiscoveredDeviceRowVM {
        let device = scanner.getMetaWear(id: id)
        return .init(device: device)
    }
}

struct DiscoveredDevicesList: View {
    @StateObject private var vm: DiscoveriesVM = .init()

    var body: some View {
        List {
            ForEach(vm.devices, id: \.self) { id in
                DiscoveredDeviceRow(vm: vm.makeRowVM(for: id))
            }
        }
        .onAppear(perform: vm.start)
        .onDisappear(perform: vm.stop)
    }
}
