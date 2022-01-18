class KnownDeviceController: ObservableObject {

    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?

    ...


}

private extension KnownDeviceController {
    ...
}
