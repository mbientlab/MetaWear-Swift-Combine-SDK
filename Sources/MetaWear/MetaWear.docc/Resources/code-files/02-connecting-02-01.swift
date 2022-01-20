class UnknownDeviceController: ObservableObject {

    private weak var metawear: MetaWear?

    init(id: CBPeripheralIdentifier,
         sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDevice(byLocalCBUUID: id)
        self.metawear = device
    }
}