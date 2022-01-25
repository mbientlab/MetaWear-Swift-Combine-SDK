import SwiftUI
import MetaWear
import Combine
import CoreBluetooth

@main
struct TestHost: App {
    var body: some Scene {
        WindowGroup {
            DiscoveredDevices()
        }
    }
}

public final class Host {
    public static let scanner = MetaWearScanner.sharedRestore
}

// MARK: - Logic

class DiscoveriesVM: ObservableObject {

    @Published var devices = [UUID]()
    @Published var updateCount = 0
    @Published var isScanning = false
    @Published var bluetoothEnabled = false

    private var scan: AnyCancellable? = nil
    private var scanState: AnyCancellable? = nil
    private var bleState: AnyCancellable? = nil
    public unowned let scanner: MetaWearScanner

    init(scanner: MetaWearScanner = Host.scanner) {
        self.scanner = scanner
        scan = scanner
            .discoveredDevicesPublisher
            .map { $0.values.map(\.localBluetoothID) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceIDs in
                self?.devices = deviceIDs
                self?.updateCount += 1
            }

        scanState = scanner.isScanningPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isScanning, on: self)

        bleState = scanner.bluetoothState
            .map { $0 == CBManagerState.poweredOn }
            .receive(on: DispatchQueue.main)
            .assign(to: \.bluetoothEnabled, on: self)
    }

    func start() {
        scanner.startScan(higherPerformanceMode: true)
    }

    func stop() {
        scanner.stopScan()
    }

    func makeRowVM(for id: UUID) -> DiscoveredDeviceRowVM {
        let device = scanner.discoveredDevices[id]
        return .init(device: device!)
    }
}

class DiscoveredDeviceRowVM: ObservableObject {

    @Published var name: String
    @Published var mac: String
    @Published var rssi: String
    @Published var cbuuid: String
    @Published var isConnected = false
    @Published var model: String

    func copy() {
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cbuuid + " " + mac, forType: .string)
#endif
    }

    func reset() {
        device
            .publishWhenConnected()
            .first()
            .command(.resetFactoryDefaults)
            .sink { _ in } receiveValue: { _ in }
            .store(in: &subs)

        device.connect()
    }

    private unowned let device: MetaWear
    private var subs = Set<AnyCancellable>()

    init(device: MetaWear) {
        self.name = device.name
        self.mac = device.info.mac
        self.model = " "
        self.device = device
        self.cbuuid = device.peripheral.identifier.uuidString
        self.rssi = String(device.rssi)

        device.connectionStatePublisher
            .map { _ in device.info.mac }
            .receive(on: DispatchQueue.main)
            .assign(to: \.mac, on: self)
            .store(in: &subs)

        device.connectionStatePublisher
            .map { _ in device.info.model.name }
            .receive(on: DispatchQueue.main)
            .assign(to: \.model, on: self)
            .store(in: &subs)

        device.rssiPublisher
            .map(String.init)
            .receive(on: DispatchQueue.main)
            .assign(to: \.rssi, on: self)
            .store(in: &subs)

        device.connectionStatePublisher
            .map { $0 == .connected }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isConnected, on: self)
            .store(in: &subs)
    }
}

// MARK: - View

struct DiscoveredDevices: View {

    @StateObject private var vm: DiscoveriesVM = .init()

    var body: some View {
        VStack {
            List {
                ForEach(vm.devices, id: \.self) { id in
                    DiscoveredDeviceRow(vm: vm.makeRowVM(for: id))
                        .listRowBackground(background(for: id))
                        .padding(.vertical, 5)
                }
            }
            if vm.devices.isEmpty == false {
                Text("Tap to copy UUID and MAC")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
        }
        .frame(width: 500, height: 200)
        .onAppear(perform: vm.start)
        .onDisappear(perform: vm.stop)
        .animation(.spring(), value: vm.devices)
        .toolbar {
            ToolbarItem(placement: .status) {
                if vm.bluetoothEnabled == false {
                    Text("Bluetooth Disabled")
                        .foregroundColor(.red)
                        .bold()
                } else if vm.isScanning {
                    ProgressView()
                        .progressViewStyle(.circular)
#if os(macOS)
                        .controlSize(.small)
#endif
                } else {
                    Text("Scanner Off")
                        .foregroundColor(.red)
                        .bold()
                }
            }
        }
    }

    func background(for id: UUID) -> some View {
        let index = vm.devices.firstIndex(of: id) ?? 0
        return RoundedRectangle(cornerRadius: 8)
            .foregroundColor(index % 2 == 0 ? .clear : .gray.opacity(0.08))
    }
}

struct DiscoveredDeviceRow: View {
    @StateObject var vm: DiscoveredDeviceRowVM

    var body: some View {
        Button(action: vm.copy, label: { label })
            .buttonStyle(.borderless)
            .contextMenu { Button("Reset") { vm.reset() } }
    }

    var label: some View {
        HStack(spacing: 20) {

            Text(vm.rssi)
                .frame(width: 40, alignment: .center)

            VStack(alignment: .leading, spacing: 5) {
                Text(vm.name)
                    .bold()
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)

                if vm.model != "Unknown" {
                    Text(vm.model)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.callout.monospacedDigit())
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(vm.mac)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.body.monospacedDigit())

                Text(vm.cbuuid)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.callout.monospacedDigit())
            }
        }
        .foregroundColor(vm.isConnected ? .accentColor : nil)
        .animation(.linear, value: vm.mac)
        .animation(.linear, value: vm.model)
    }
}

