class SensorLoggingController: ObservableObject {

    let name:                                 String

    @Published private(set) var enableCTAs:   Bool
    private var enableCTAsSub:                AnyCancellable? = nil

    init(mac: MACAddress, sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDeviceAndMetadata(mac)!
        self.metawear = device!
        self.name = metadata.name
        self.enableCTAs = device?.connectionState == .connected
    }

    private unowned let metawear: MetaWear
}

extension SensorLoggingController {

    func onAppear() {
        metawear.connect()

        enableCTAsSub = metawear.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.enableCTAs = $0 == .connected }
    }
}
