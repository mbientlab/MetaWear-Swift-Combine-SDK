class KnownDeviceUseCase: ObservableObject {

    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var metadata:   MetaWearMetadata
    @Published private(set) var rssi:       Int
    @Published private(set) var connection: CBPeripheralState

    private weak var metawear: MetaWear?
    ...

}

extension KnownDeviceUseCase {

    func resetDeletingLogs() {
        resetSub = metawear?
            .publishWhenConnected()
            .first()
            .deleteLoggedEntries()
            .command(.resetActivities)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        metawear?.connect()
    }
}
