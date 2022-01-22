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
            .optionallyLog(configs.accelerometer)
            .optionallyLog(configs.gyroscope)
            .optionallyLog(configs.linearAcc)
            .optionallyLog(configs.quaternion)
            .sink(receiveCompletion: { [weak self] in
                displayError(from: $0, on: self, \.state)
            }, receiveValue: { [weak self] in
                self?.enableDownloading()
            })

        metawear.connect()
    }
}

...
