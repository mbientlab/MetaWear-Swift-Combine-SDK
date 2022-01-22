import MetaWear
import MetaWearSync
import Combine

class DeviceListUseCase: ObservableObject {

    @Published private(set) var unknownDevices: [CBPeripheralIdentifier] = []
    @Published private(set) var knownDevices:   [MACAddress] = []

    private weak var scanner: MetaWearScanner?
    private weak var sync:    MetaWearSyncStore?
    private var unknownSub:   AnyCancellable? = nil
    private var knownSub:     AnyCancellable? = nil

    init(_ sync: MetaWearSyncStore, _ scanner: MetaWearScanner) {
        self.sync = sync
        self.scanner = scanner
    }
}

extension DeviceListUseCase {

    func onAppear() {
        scanner?.startScan(higherPerformanceMode: true)

        unknownSub = sync?.unknownDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.unknownDevices = $0.sorted() }

        knownSub = sync?.knownDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metadata in
                self?.knownDevices = metadata
                    .sorted(using: KeyPathComparator(\.name))
                    .map(\.mac)
            }
    }

    func onDisappear() {
        scanner?.stopScan()
    }
}
