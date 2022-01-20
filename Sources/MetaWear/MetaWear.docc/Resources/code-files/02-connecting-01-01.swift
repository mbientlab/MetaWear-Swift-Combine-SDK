import MetaWear

class DeviceListController: ObservableObject {

    @Published private(set) var unknownDevices: [CBPeripheralIdentifier] = []
    @Published private(set) var knownDevices: [MACAddress] = []

    init() {
    }
}
