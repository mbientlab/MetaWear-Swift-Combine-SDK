class KnownDeviceController: ObservableObject {

    var name: String { metadata.name }
    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState
    @Published private var metadata: MetaWear.Metadata
    @Published var showRenamePrompt = false

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?

    ...

    func rename(_ newName: String) {
        do { try sync?.rename(known: metadata, to: newName) }
        catch { showRenamePrompt = true }
    }
}

private extension KnownDeviceController {
    ...
}
