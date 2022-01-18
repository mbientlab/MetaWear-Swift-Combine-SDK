class KnownDeviceController: ObservableObject {

    var name: String { metadata.name }
    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState
    @Published private var metadata: MetaWear.Metadata

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?


    ...

    func onAppear() {

        trackRSSI()
        trackConnection()
    }
}

private extension KnownDeviceController {


}
