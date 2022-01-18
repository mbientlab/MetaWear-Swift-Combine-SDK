class SensorLoggingController: ObservableObject {

    let name:                                 String
    @Published var logGyroscope             = true
    @Published var logAccelerometer         = true

    @Published private(set) var enableCTAs:   Bool
    private var enableCTAsSub:                AnyCancellable? = nil

    init(mac: MACAddress, sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDeviceAndMetadata(mac)!
        self.metawear = device!
        self.name = metadata.name
        self.enableCTAs = device?.connectionState == .connected
    }

    private let accelerometerConfig = MWAccelerometer(rate: .hz100, gravity: .g16)
    private let gyroscopeConfig     = MWGyroscope(rate: .hz100, range: .dps2000)

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
