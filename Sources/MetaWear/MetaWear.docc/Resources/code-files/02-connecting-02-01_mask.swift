class UnknownDeviceController: ObservableObject {

    private weak var metawear: MetaWear?

    init(id: CBPeripheralIdentifier,
         sync: MetaWearSyncStore) {
        self.metawear = device
    }
}
