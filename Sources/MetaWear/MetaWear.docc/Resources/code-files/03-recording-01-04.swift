class SensorLoggingController: ObservableObject {

    @Published private(set) var selectedSensors: Set<MWNamedSignal> = []
    private let accelerometerConfig = MWAccelerometer(rate: .hz100, gravity: .g16)
    private let gyroscopeConfig     = MWGyroscope(rate: .hz100, range: .dps2000)
    private var logSub:               AnyCancellable? = nil
    ...
}

extension SensorLoggingController {

    func log() {
        guard selectedSensors.isEmpty == false else { return }

        logSub = metawear
            .publishWhenConnected()
            .first()
            .optionallyLog(selectedSensors.contains(.gyroscope) ? gyroscopeConfig : nil)
            .optionallyLog(selectedSensors.contains(.acceleration) ? accelerometerConfig : nil)
        ...

        metawear.connect()
    }
}
