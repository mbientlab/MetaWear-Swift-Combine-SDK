class NewSessionUseCase: ObservableObject {

    let deviceName:                       String
    private weak var metawear:            MetaWear?       = nil

    init(_ knownDevice: MWKnownDevice) {
        self.metawear = knownDevice.mw
        self.deviceName = knownDevice.meta.name
    }
}

extension NewSessionUseCase {

    ...
}
