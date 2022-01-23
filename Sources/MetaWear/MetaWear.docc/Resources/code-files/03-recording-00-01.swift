class NextStepsUseCase: ObservableObject {

    @Published private(set) var cta:   UseCaseCTA       = .connect
    @Published private(set) var state: UseCaseState     = .ready
    let deviceName:                    String

    private weak var metawear:         MetaWear?       = nil
    private var      getCTASub:        AnyCancellable? = nil

    init(_ knownDevice: MWKnownDevice) {
        self.metawear = knownDevice.mw
        self.deviceName = knownDevice.meta.name
    }
}

extension NextStepsUseCase {

    func onAppear() {
        getCTAState()
    }
}

private extension NextStepsUseCase {

    func getCTAState() {
        getCTASub = metawear
            .publishWhenConnected()
            .first()
            .read(.logLength)
            .map { $0.value > 0 }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] bytesAreUsed in
                self?.updateCTAState(isLogging: bytesAreUsed)
            })

        metawear.connect()
    }
}
