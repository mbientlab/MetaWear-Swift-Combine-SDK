import Foundation
import MetaWear
import MetaWearSync
import Combine
import CoreBluetooth

class KnownDeviceController: ObservableObject {

    var name: String { metadata.name }
    var isCloudSynced: Bool { metawear == nil }

    @Published private(set) var rssi: Int
    @Published private(set) var connection: CBPeripheralState
    @Published private var metadata: MetaWear.Metadata
    @Published var showRenamePrompt = false

    private weak var metawear: MetaWear? = nil
    private weak var sync:     MetaWearSyncStore?
    private var connectionSub: AnyCancellable? = nil
    private var identitySub:   AnyCancellable? = nil
    private var identifySub:   AnyCancellable? = nil
    private var resetSub:      AnyCancellable? = nil
    private var rssiSub:       AnyCancellable? = nil

    init(knownDevice: MACAddress, sync: MetaWearSyncStore) {
        self.sync = sync
        (self.metawear, self.metadata) = sync.getDeviceAndMetadata(knownDevice)!
        self.rssi = self.metawear?.rssi ?? -100
        self.connection = self.metawear?.connectionState ?? .disconnected
    }

    func onAppear() {
        trackIdentity()
        trackConnection()
        trackRSSI()
    }

    func connect() {
        metawear?.connect()
    }

    func disconnect() {
        metawear?.disconnect()
    }

    func forget() {
        sync?.forget(globally: metadata)
    }

    func rename(_ newName: String) {
        do { try sync?.rename(known: metadata, to: newName) }
        catch { showRenamePrompt = true }
    }

    func reset() {
        resetSub = metawear?
            .publishWhenConnected()
            .first()
            .command(.resetActivities)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        metawear?.connect()
    }

    func identify() {
        identifySub = metawear?.publishWhenConnected()
            .first()
            .command(.ledFlash(.Presets.one.pattern))
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        if metawear?.connectionState ?? .disconnected < .connecting { metawear?.connect() }
    }
}

private extension KnownDeviceController {

    func trackRSSI() {
        rssiSub = metawear?.rssiPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.rssi = $0 }
    }

    func trackConnection() {
        connectionSub = metawear?.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.connection = $0 }
    }

    func trackIdentity() {
        identitySub = sync?.publisher(for: metadata.mac)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metawear, metadata in
                let metaWearReferenceNowAvailable = self?.metawear == nil && metawear != nil
                self?.metawear = metawear
                self?.metadata = metadata

                if metaWearReferenceNowAvailable {
                    self?.trackRSSI()
                    self?.trackConnection()
                }
            }
    }
}
