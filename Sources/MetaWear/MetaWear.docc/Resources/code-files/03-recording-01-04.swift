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

        actionSub = metawear
            .publishWhenConnected()
            .first()
            .optionallyLog(<some MWLoggable>)
        ...

        metawear.connect()
    }
}
