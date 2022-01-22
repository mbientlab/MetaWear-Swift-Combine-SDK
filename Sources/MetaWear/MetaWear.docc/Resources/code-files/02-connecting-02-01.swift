class UnknownDeviceUseCase: ObservableObject {

    private weak var metawear:  MetaWear?

    init(nearby: (MetaWear, metadata: MetaWearMetadata?)) {
        self.metawear = nearby.metawear
    }

}

// * Called by the factory object creating the use case *

class MetaWearSyncStore {

    func getDevice(byLocalCBUUID: CBPeripheralIdentifier)
    -> (device: MetaWear?, metadata: MetaWearMetadata?)
}
