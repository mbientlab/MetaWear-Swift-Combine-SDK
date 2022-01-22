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

    func onAppear() {
        guard state == .notReady, let metawear = metawear else { return }
        actionSub =  metawear
            .publishWhenConnected()
            .first()
            .downloadLogs(startDate: startDate)
            .handleEvents(receiveOutput: { [weak self] (_, percentComplete) in
                DispatchQueue.main.async { [weak self] in
                    self?.state = .workingProgress($0)
                }
            })
            .drop { $0.percentComplete < 1 }
            .map { $0.data }
            .sink(receiveCompletion: { [weak self] in
                displayError(from: $0, on: self, \.state)
            }, receiveValue: { [weak self] in
                self?.prepareForExport(dataTables: $0)
            })

        metawear?.connect()
    }
}
