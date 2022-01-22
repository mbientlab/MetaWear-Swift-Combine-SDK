class DownloadUseCase: ObservableObject {

    private(set) var startDate:         Date
    @Published private(set) var state:  UseCaseState      = .notReady

    init(_ knownDevice: MWKnownDevice, startDate: Date) {
        self.startDate = startDate
        self.metawear = knownDevice.mw
        self.deviceName = knownDevice.meta.name
    }
}

extension DownloadUseCase {

    ...
}

