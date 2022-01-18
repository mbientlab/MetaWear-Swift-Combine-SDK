class KnownDeviceController: ObservableObject {

    var name: String { metadata.name }
    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState
    @Published private var metadata: MetaWear.Metadata

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?
    private var identifySub:   AnyCancellable? = nil

    ...

    func identify() {
        identifySub = metawear?.publishWhenConnected()
            .first()
            .command(.ledFlash(.Presets.one.pattern))
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        if metawear?.connectionState ?? .disconnected < .connecting { metawear?.connect() }
    }
}

private extension KnownDeviceController {
    ...
}
