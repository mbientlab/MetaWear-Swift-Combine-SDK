class SensorLoggingController: ObservableObject {

    @Published private(set) var selectedSensors: Set<MWNamedSignal> = []
    private let accelerometerConfig = MWAccelerometer(rate: .hz100, gravity: .g16)
    private let gyroscopeConfig     = MWGyroscope(rate: .hz100, range: .dps2000)
    private var logSub:               AnyCancellable? = nil
    private var startDate:            Date
    ...

    enum State: Equatable {
        case unknown
        case logging
        case loggingError(String)
    }
}

extension SensorLoggingController {

    func log() {
        guard selectedSensors.isEmpty == false else { return }

        logSub = metawear
            .publishWhenConnected()
            .first()
            .optionallyLog(selectedSensors.contains(.gyroscope) ? gyroscopeConfig : nil)
            .optionallyLog(selectedSensors.contains(.acceleration) ? accelerometerConfig : nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard case let failure(error) = completion else { return }
                self?.state = .loggingError(error.localizedDescription)
            } receiveValue: { [weak self] _ in
                self?.state = .logging
                self?.startDate = .init()
            }

        metawear.connect()
    }
}
