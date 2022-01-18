class KnownDeviceController: ObservableObject {

    var isCloudSynced: Bool { metawear == nil }
    
    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?
    private var connectionSub: AnyCancellable? = nil
    private var rssiSub:       AnyCancellable? = nil

    init(knownDevice: MACAddress, sync: MetaWearSyncStore) {
        self.sync = sync
        (self.metawear, self.metadata) = sync.getDeviceAndMetadata(knownDevice)!
        self.rssi = self.metawear?.rssi ?? -100
        self.connection = self.metawear?.connectionState ?? .disconnected
    }

    func onAppear() {
        trackRSSI()
        trackConnection()
    }
}

private extension KnownDeviceController {

    func trackRSSI() {
        rssiSub = metawear?.rssiPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.rssi = $0 }
    }

    func trackConnection() {
        connectionSub = metawear?.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.connection = $0 }
    }
}
