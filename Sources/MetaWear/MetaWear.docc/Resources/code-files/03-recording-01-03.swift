class SensorLoggingController: ObservableObject {

    @Published private(set) var selectedSensors: Set<MWNamedSignal> = []
    private let accelerometerConfig = MWAccelerometer(rate: .hz100, gravity: .g16)
    private let gyroscopeConfig     = MWGyroscope(rate: .hz100, range: .dps2000)
    ...
}

extension SensorLoggingController {

}
