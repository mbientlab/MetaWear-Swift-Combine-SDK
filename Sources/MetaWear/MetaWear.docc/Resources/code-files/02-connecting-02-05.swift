class UnknownDeviceController: ObservableObject {

    let name: String
    let isCloudSynced: Bool
    @Published private(set) var rssi: Int
    @Published private(set) var isConnecting = false

    private weak var metawear: MetaWear?
    private weak var sync:     MetaWearSyncStore?
    private      var rssiSub:  AnyCancellable? = nil

    init(id: CBPeripheralIdentifier,
         sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDevice(byLocalCBUUID: id)
        self.metawear = device
        self.name = metadata?.name ?? device!.name
        self.isCloudSynced = metadata != nil
        self.rssi = metawear.rssi
        self.sync = sync
    }

    func onAppear() {
        rssiSub = metawear?.rssiPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.rssi = $0 }
    }

    func remember() {
        guard let id = metawear?.localBluetoothID else { return }
        isConnecting = true

        sync?.connectAndRemember(unknown: id, didAdd: { (device, _) in
            device?.publishIfConnected()
                .command(.ledFlash(.Presets.one.pattern))
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
               
        })
    }
}

