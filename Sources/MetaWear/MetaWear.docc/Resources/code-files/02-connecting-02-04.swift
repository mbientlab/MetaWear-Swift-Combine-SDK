class UnknownDeviceUseCase: ObservableObject {

    let name: String
    let isCloudSynced: Bool
    @Published private(set) var rssi: Int

    private weak var metawear:  MetaWear?
    private      var rssiSub:   AnyCancellable? = nil

    init(nearby: (MetaWear, metadata: MetaWearMetadata?)) {
        self.metawear = nearby.metawear
        self.name = nearby.metadata?.name ?? nearby.metawear.name
        self.isCloudSynced = nearby.metadata != nil
        self.rssi = nearby.metawear.rssi
    }

    func onAppear() {
        rssiSub = metawear?.rssiPublisher
            .onMain()
            .sink { [weak self] in self?.rssi = $0 }
    }
}
