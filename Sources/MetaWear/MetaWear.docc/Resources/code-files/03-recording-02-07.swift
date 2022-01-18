class SensorLoggingController: ObservableObject {

    @Published private(set) var state: State = .unknown
    private var startDate:             Date  = .init()
    private var downloadSub:           AnyCancellable? = nil
    ...

    enum State: Equatable {
        case unknown
        case logging
        case downloading(Double)
        case downloaded
        case loggingError(String)
        case downloadError(String)
    }
}

extension SensorLoggingController {

    func download() {
        downloadSub = metawear
            .publishWhenConnected()
            .first()
            .downloadLogs(startDate: startDate)
            .handleEvents(receiveOutput: { [weak self] (_, percentComplete) in
                DispatchQueue.main.async { [weak self] in
                    self?.state = .downloading(percentComplete)
                }
            })
            .drop { $0.percentComplete < 1 }
            .sink { [weak self] completion in
                guard case let failure(error) = completion else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.state = .downloadError(error.localizedDescription)
                }
            } receiveValue: { [weak self] (dataTables, percentComplete) in
                self?.prepareExportAndUpdateUI(for: dataTables)
            }
    }
}
