class NewSessionUseCase: ObservableObject {

    @Published private(set) var sensors:  Set<MWNamedSignal> = []
    let sensorChoices:                    [MWNamedSignal] = [
        .acceleration, .gyroscope, .linearAcceleration, .quaternion
    ]
    ...
}

extension NewSessionUseCase {

    ...
}
