class SensorLoggingController: ObservableObject {

    let name: String
    private unowned let metawear: MetaWear

    init(mac: MACAddress, sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDeviceAndMetadata(mac)!
        self.metawear = device!
        self.name = metadata.name
    }
}

extension SensorLoggingController {

    func onAppear() {
        metawear.connect()

    }
}
