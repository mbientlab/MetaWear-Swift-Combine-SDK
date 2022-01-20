class SensorLoggingController: ObservableObject {

    @Published private(set) var state: State = .unknown
    private var startDate:             Date  = .init()
    ...

    enum State: Equatable {
        case unknown
        case logging
        case loggingError(String)
    }
}

extension SensorLoggingController {

}
