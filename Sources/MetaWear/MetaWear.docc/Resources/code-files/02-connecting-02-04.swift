class UnknownDeviceController: ObservableObject {

    let name: String
    let isCloudSynced: Bool
    @Published private(set) var rssi: Int

    private weak var metawear: MetaWear?
    private      var rssiSub:  AnyCancellable? = nil

    init(id: CBPeripheralIdentifier,
         sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDevice(byLocalCBUUID: id)
        self.metawear = device
        self.name = metadata?.name ?? device!.name
        self.isCloudSynced = metadata != nil
        self.rssi = metawear.rssi
    }

    func onAppear() {
        rssiSub = metawear?.rssiPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.rssi = $0 }
    }
}
