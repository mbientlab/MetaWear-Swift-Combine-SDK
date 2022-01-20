class KnownDeviceController: ObservableObject {

    var name: String { metadata.name }
    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState
    @Published private var metadata: MetaWearMetadata

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?
    private var identitySub:   AnyCancellable? = nil

    ...

    func onAppear() {
        trackIdentity()
        trackRSSI()
        trackConnection()
    }
}

private extension KnownDeviceController {

    func trackIdentity() {
        identitySub = sync?.publisher(for: metadata.mac)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metawear, metadata in
                let metaWearReferenceNowAvailable = self?.metawear == nil && metawear != nil
                self?.metawear = metawear
                self?.metadata = metadata

                if metaWearReferenceNowAvailable {
                    self?.trackRSSI()
                    self?.trackConnection()
                }
            }
    }
}
