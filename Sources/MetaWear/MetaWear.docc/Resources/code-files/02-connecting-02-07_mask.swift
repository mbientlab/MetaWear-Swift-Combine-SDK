class UnknownDeviceUseCase: ObservableObject {

    let name: String
    let isCloudSynced: Bool
    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState

    private weak var metawear:  MetaWear?
    private weak var sync:      MetaWearSyncStore?
    private      var rssiSub:   AnyCancellable? = nil

    init(nearby: (MetaWear, metadata: MetaWearMetadata?),
         sync:   MetaWearSyncStore,

        self.metawear = nearby.metawear
        self.name = nearby.metadata?.name ?? nearby.metawear.name
        self.isCloudSynced = nearby.metadata?.hasCloudSyncedInfo == true
        self.rssi = nearby.metawear.rssi
        self.connection = nearby.metawear.connectionState
        self.sync = sync
    }

    func onAppear() {
        rssiSub = metawear?.rssiPublisher
            .onMain()
            .sink { [weak self] in self?.rssi = $0 }
    }

    func remember() {
        guard let id = metawear?.localBluetoothID,
              let sync = sync,
              let tasks = tasks else { return }
        self.connection = .connecting
        sync?.connectAndRemember(unknown: id, didAdd: { (device, metadata) in
            device?.publishIfConnected()
                .command(.led(.orange, .pulse(repetitions: 2)))
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        })
    }
}
