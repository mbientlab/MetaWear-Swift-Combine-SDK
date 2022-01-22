class KnownDeviceUseCase: ObservableObject {

    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var metadata:   MetaWearMetadata
    @Published private(set) var rssi:       Int
    @Published private(set) var connection: CBPeripheralState

    private weak var metawear: MetaWear?
    private var identitySub:   AnyCancellable? = nil
    private var connectionSub: AnyCancellable? = nil
    private var rssiSub:       AnyCancellable? = nil

    init(_ sync: MetaWearSyncStore,
         _ known: (device: MetaWear?, metadata: MetaWearMetadata)) {
        self.sync = sync
        (self.metawear, self.metadata) = known
        self.rssi = self.metawear?.rssi ?? -100
        self.connection = self.metawear?.connectionState ?? .disconnected
    }

    func onAppear {
        trackIdentity()
        trackRSSI()
        trackConnection()
    }
}

private extension KnownDeviceUseCase {

    func trackIdentity() {
        identitySub = sync?.publisher(for: metadata.mac)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceReference, metadata in
                let justFoundMetaWear = self?.metawear == nil && deviceReference != nil
                self?.metawear = deviceReference
                self?.metadata = metadata

                if justFoundMetaWear {
                    self?.trackRSSI()
                    self?.trackConnection()
                }
            }
    }
}
