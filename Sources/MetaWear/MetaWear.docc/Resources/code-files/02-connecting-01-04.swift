import Combine

class NearbyDeviceListController: ObservableObject {

    @Published private(set) var unknownDevices: [CBPeripheralIdentifier] = []
    @Published private(set) var knownDevices: [MACAddress] = []

    private weak var sync:    MetaWearSyncStore?
    private weak var scanner: MetaWearScanner?
    private var unknownSub:   AnyCancellable? = nil

    init(_ sync: MetaWearSyncStore, _ scanner: MetaWearScanner) {
        self.sync = sync
        self.scanner = scanner
    }
}

extension NearbyDeviceListController {

    func onAppear() {
        scanner?.startScan(higherPerformanceMode: true)

        unknownSub = sync?.unknownDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.unknownDevices = $0.sorted() }
    }

    func onDisappear() {
        scanner?.stopScan()
    }
}
