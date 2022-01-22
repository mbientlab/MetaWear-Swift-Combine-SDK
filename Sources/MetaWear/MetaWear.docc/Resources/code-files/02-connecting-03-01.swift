class KnownDeviceUseCase: ObservableObject {

    @Published private(set) var metadata:   MetaWearMetadata
    @Published private(set) var rssi:       Int
    @Published private(set) var connection: CBPeripheralState

    private weak var metawear: MetaWear?
    private var connectionSub: AnyCancellable? = nil
    private var rssiSub:       AnyCancellable? = nil

    init(_ sync: MetaWearSyncStore,
         _ known: (device: MetaWear?, metadata: MetaWearMetadata)) {
        self.sync = sync
        (self.metawear, self.metadata) = known
        self.rssi = self.metawear?.rssi ?? -100
        self.connection = self.metawear?.connectionState ?? .disconnected
    }

    func onAppear {
        trackRSSI()
        trackConnection()
    }
}

private extension KnownDeviceUseCase {

    func trackConnection() {
        connectionSub = metawear?.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.connection = $0 }
    }
}
