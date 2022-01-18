class KnownDeviceController: ObservableObject {

    @Published private(set) var rssi: Int

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?
    private var rssiSub:       AnyCancellable? = nil

    init(knownDevice: MACAddress, sync: MetaWearSyncStore) {
        self.sync = sync
        self.rssi = self.metawear?.rssi ?? -100
    }

    func onAppear() {
        trackRSSI()
    }
}

private extension KnownDeviceController {

    func trackRSSI() {
        rssiSub = metawear?.rssiPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.rssi = $0 }
    }
}
