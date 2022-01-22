class NewSessionUseCase: ObservableObject {

    @Published private(set) var sensors:  Set<MWNamedSignal> = []
    let sensorChoices:                    [MWNamedSignal] = [
        .acceleration, .gyroscope, .linearAcceleration, .quaternion
    ]

    @Published private(set) var state:    UseCaseState    = .notReady
    ...
}

extension NewSessionUseCase {

    func didTapCTA() {
        guard sensors.hasElements, let metawear = metawear else { return }
        state = .workingIndefinite
        let configs = SensorConfigurations(selections: sensors)
        actionSub = metawear
            .publishWhenConnected()
            .first()
            .optionallyLog(<some MWLoggable>)
        ...

        metawear.connect()
    }
}

struct SensorConfigurations {
    var accelerometer: MWAccelerometer? = nil
    var gyroscope:     MWGyroscope?     = nil
    var linearAcc:     MWSensorFusion.LinearAcceleration? = nil
    var quaternion:    MWSensorFusion.Quaternion? = nil

    init(selections: Set<MWNamedSignal>)  {
        if selections.contains(.linearAcceleration) {
            linearAcc  = .init(mode: .imuplus)
            return
        } else if selections.contains(.quaternion) {
            quaternion = .init(mode: .imuplus)
            return
        }

        if selections.contains(.acceleration) {
            accelerometer = .init(rate: .hz100, gravity: .g16)
        }
        if selections.contains(.gyroscope) {
            gyroscope = .init(rate: .hz100, range: .dps2000)
        }
    }
}
