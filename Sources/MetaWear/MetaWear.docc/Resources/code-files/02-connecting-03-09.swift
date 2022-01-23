class KnownDeviceUseCase: ObservableObject {

    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var metadata:   MetaWearMetadata
    @Published private(set) var rssi:       Int
    @Published private(set) var connection: CBPeripheralState
    @Published var showRenameInvalidPrompt: Bool = false

    private weak var metawear: MetaWear?
    ...

}

extension KnownDeviceUseCase {

    func rename(_ newName: String) {
        do { try sync?.rename(known: metadata, to: newName) }
        catch { showRenameInvalidPrompt = true }
    }
}
