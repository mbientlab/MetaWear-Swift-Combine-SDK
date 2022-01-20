class SensorLoggingController: ObservableObject {

    @Published private(set) var selectedSensors: Set<MWNamedSignal> = []
    ...
}

extension SensorLoggingController {

    func toggleSensor(_ sensor: MWNamedSignal) -> Binding<Bool>  {
        Binding(
            get: { [weak self] in self?.selectedSensors.contains(sensor) == true },
            set: { [weak self] shouldUse in
                guard shouldUse else { self?.selectedSensors.remove(sensor); return }
                self?.selectedSensors.removeConflicts(for: sensor)
                self?.selectedSensors.insert(sensor)
            }
        )
    }
}
