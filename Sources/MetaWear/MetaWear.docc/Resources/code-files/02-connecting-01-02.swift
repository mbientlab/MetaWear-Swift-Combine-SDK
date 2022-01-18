class NearbyDeviceListController: ObservableObject {

    @Published private(set) var unknownDevices: [CBPeripheralIdentifier] = []
    @Published private(set) var knownDevices: [MACAddress] = []

    private weak var scanner: MetaWearScanner?

    init(_ scanner: MetaWearScanner) {
        self.scanner = scanner
    }
}

extension NearbyDeviceListController {

    func onAppear() {
        scanner?.startScan(higherPerformanceMode: true)
    }
}
