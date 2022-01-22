class KnownDeviceUseCase: ObservableObject {

    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var metadata:   MetaWearMetadata
    @Published private(set) var rssi:       Int
    @Published private(set) var connection: CBPeripheralState

    private weak var metawear: MetaWear?
    ...

}

extension KnownDeviceUseCase {

    func connect() {
        metawear?.connect()
    }

    func disconnect() {
        metawear?.disconnect()
    }
}
