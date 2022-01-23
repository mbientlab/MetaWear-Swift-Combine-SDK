class NewSessionUseCase: ObservableObject {

    @Published private(set) var sensors:  Set<MWNamedSignal> = []
    let sensorChoices:                    [MWNamedSignal] = [
        .acceleration, .gyroscope, .linearAcceleration, .quaternion
    ]

    @Published private(set) var state:    UseCaseState    = .notReady
    ...
}

extension NewSessionUseCase {

    func toggleSensor(_ sensor: MWNamedSignal)  {
        guard sensors.contains(sensor) else {
            sensors.removeConflicts(for: sensor)
            sensors.insert(sensor)
            if state == .notReady { state = .ready }
            return
        }
        sensors.remove(sensor)
        if sensors.isEmpty { state = .notReady }
    }
}
