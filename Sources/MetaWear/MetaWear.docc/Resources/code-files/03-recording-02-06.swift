class SensorLoggingController: ObservableObject {

    @Published private(set) var state: State = .unknown
    private var startDate:             Date  = .init()
    private var downloadSub:           AnyCancellable? = nil
    ...

    enum State: Equatable {
        case unknown
        case logging
        case downloading(Double)
        case loggingError(String)
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
        ...
    }
}
