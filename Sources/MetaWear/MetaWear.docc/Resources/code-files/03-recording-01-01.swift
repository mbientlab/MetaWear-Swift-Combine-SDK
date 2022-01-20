class SensorLoggingController: ObservableObject {

    @Published private(set) var enableCTAs:   Bool
    private var enableCTAsSub:                AnyCancellable? = nil
    let name: String
    private unowned let metawear: MetaWear

    init(mac: MACAddress, sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDeviceAndMetadata(mac)!
        self.metawear = device!
        self.name = metadata.name
        self.enableCTAs = device?.connectionState == .connected
    }
}

extension SensorLoggingController {

    func onAppear() {
        metawear.connect()

        enableCTAsSub = metawear.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.enableCTAs = $0 == .connected }
    }
}
