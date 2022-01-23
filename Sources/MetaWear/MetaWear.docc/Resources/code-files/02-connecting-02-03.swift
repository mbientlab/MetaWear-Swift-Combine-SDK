class UnknownDeviceUseCase: ObservableObject {

    let name: String
    let isCloudSynced: Bool

    private weak var metawear:  MetaWear?

    init(nearby: (MetaWear, metadata: MetaWearMetadata?)) {
        self.metawear = nearby.metawear
        self.name = nearby.metadata?.name ?? nearby.metawear.name
        self.isCloudSynced = nearby.metadata?.hasCloudSyncedInfo == true
    }

}
