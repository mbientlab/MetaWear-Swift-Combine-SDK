class KnownDeviceController: ObservableObject {

    var name: String { metadata.name }
    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState
    @Published private var metadata: MetaWear.Metadata

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?

    ...

    func connect() {
        metawear?.connect()
    }

    func disconnect() {
        metawear?.disconnect()
    }

    func forget() {
        sync?.forget(globally: metadata)
    }
}

private extension KnownDeviceController {
    ...
}
