class KnownDeviceUseCase: ObservableObject {

    @Published private(set) var metadata:   MetaWearMetadata
    @Published private(set) var rssi:       Int


    private weak var metawear: MetaWear?

    private var rssiSub:       AnyCancellable? = nil

    init(_ sync: MetaWearSyncStore,
         _ known: (device: MetaWear?, metadata: MetaWearMetadata)) {
        self.sync = sync
        (self.metawear, self.metadata) = known
        self.rssi = self.metawear?.rssi ?? -100

    }

    func onAppear {
        trackRSSI()

    }
}

private extension KnownDeviceUseCase {


}
