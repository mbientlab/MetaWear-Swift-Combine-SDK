class NewSessionUseCase: ObservableObject {

    @Published private(set) var sensors:  Set<MWNamedSignal> = []
    let sensorChoices:                    [MWNamedSignal] = [
        .acceleration, .gyroscope, .linearAcceleration, .quaternion
    ]
    ...
}

extension NewSessionUseCase {

    func toggleSensor(_ sensor: MWNamedSignal)  {
        guard sensors.contains(sensor) else {
            sensors.removeConflicts(for: sensor)
            sensors.insert(sensor)
            return
        }
        sensors.remove(sensor)
    }
}
