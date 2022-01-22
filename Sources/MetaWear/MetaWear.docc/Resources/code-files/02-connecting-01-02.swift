import MetaWear

class DeviceListUseCase: ObservableObject {

    @Published private(set) var unknownDevices: [CBPeripheralIdentifier] = []
    @Published private(set) var knownDevices:   [MACAddress] = []

    private weak var scanner: MetaWearScanner?

    init(_ scanner: MetaWearScanner) {
        self.scanner = scanner
    }
}

extension DeviceListUseCase {

    func onAppear() {
        scanner?.startScan(higherPerformanceMode: true)
    }
}
