class UnknownDeviceController: ObservableObject {

    let name: String
    let isCloudSynced: Bool

    private weak var metawear: MetaWear?

    init(id: CBPeripheralIdentifier,
         sync: MetaWearSyncStore) {
        let (device, metadata) = sync.getDevice(byLocalCBUUID: id)
        self.metawear = device
        self.name = metadata?.name ?? device!.name
        self.isCloudSynced = metadata != nil
    }
}
