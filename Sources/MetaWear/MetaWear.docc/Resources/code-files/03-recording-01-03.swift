class SensorLoggingController: ObservableObject {

    let name:                                 String
    @Published var logGyroscope             = true
    @Published var logAccelerometer         = true

    @Published private(set) var state:        State = .unknown
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
    private var logSub: AnyCancellable? = nil

    enum State: Equatable {
        case unknown
        case logging
        case loggingError(String)
    }
}

extension SensorLoggingController {

    func onAppear() {
        metawear.connect()

        enableCTAsSub = metawear.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.enableCTAs = $0 == .connected }
    }

    func log() {
        logSub = metawear
            .publishWhenConnected()
            .first()
            .optionallyLog(logGyroscope ? gyroscopeConfig : nil)
            .optionallyLog(logAccelerometer ? accelerometerConfig : nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                    case .failure(let error):
                        self?.state = .loggingError(error.localizedDescription)
                    case .finished: return
                }
            } receiveValue: { [weak self] _ in
                self?.state = .logging
                self?.startDate = .init()
            }

        metawear.connect()
    }
}
