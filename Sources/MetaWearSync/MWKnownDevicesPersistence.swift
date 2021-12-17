// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear
import Combine

// MARK: - Model

public protocol MWKnownDevicesPersistence: AnyObject {
    func load() throws
    func save(_ loadable: MWKnownDevicesLoadable) throws
    var metawears: AnyPublisher<MWKnownDevicesLoadable, Never> { get }
}

/// Container for metadata for MetaWear devices and groups.
public struct MWKnownDevicesLoadable {
    public var groups: [MetaWear.Group]
    public var devices: [MetaWear.Metadata]

    public init(groups: [MetaWear.Group], devices: [MetaWear.Metadata]) {
        self.groups = groups
        self.devices = devices
    }
}

// MARK: - Implementation

/// Using local and cloud stores that you instantiate and manage elsewhere,
/// this saves and listens for shared MetaWear metadata updates.
///
/// You must call `cloud.synchronize()` after instantiating this object
/// for iCloud data sharing to work.
///
public class MWCloudLoader: MWKnownDevicesPersistence {

    public let metawears: AnyPublisher<MWKnownDevicesLoadable, Never>
    private let _loadable = PassthroughSubject<MWKnownDevicesLoadable, Never>()
    private unowned let local: UserDefaults
    private unowned let cloud: NSUbiquitousKeyValueStore

    private let key = UserDefaults.MetaWear.Keys.syncedMetadata

    public init(local: UserDefaults = UserDefaults.MetaWear.suite,
                cloud: NSUbiquitousKeyValueStore) {
        self.local = local
        self.cloud = cloud
        self.metawears = _loadable.eraseToAnyPublisher()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// When iCloud synchronizes defaults at app startup, this function is called.
    @objc internal func cloudDidChange(_ note: Notification) {
        guard let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [NSString] else { return }
        if changedKeys.contains(.init(string: key)),
           let data = cloud.value(forKey: key) as? Data {
            do {
                let loadable = try MWMetadataSaveContainer.decode(loadable: data)
                _loadable.send(loadable)
            } catch { NSLog("MetaWear Metadata Cloud Decoding Failed: \(error.localizedDescription)") }
        }
    }

    public func load() throws {
        guard let data = local.value(forKey: key) as? Data else { return }
        let loadable = try MWMetadataSaveContainer.decode(loadable: data)
        _loadable.send(loadable)
    }

    public func save(_ loadable: MWKnownDevicesLoadable) throws {
        let data = try MWMetadataSaveContainer.encode(metadata: loadable)
        local.set(data, forKey: key)
        cloud.set(data, forKey: key)
    }
}

// MARK: - Data

public struct MWMetadataSaveContainer: Codable {
    public var versionSentinel = 1
    public let data: Data

    public init(metadata: [MetaWear.Metadata], encoder: JSONEncoder) throws {
        let dto = metadata.map(MWMetadataDTO1.init)
        self.data = try encoder.encode(dto)
    }

    static func encode(metadata: MWKnownDevicesLoadable) throws -> Data {
        let encoder = JSONEncoder()
        let container = MWKnownDevicesLoadableDTO1(model: metadata)
        return try encoder.encode(container)
    }

    static func decode(loadable: Data) throws -> MWKnownDevicesLoadable {
        try JSONDecoder().decode(MWKnownDevicesLoadableDTO1.self, from: loadable).asModel()
    }
}

fileprivate struct MWKnownDevicesLoadableDTO1: Codable {
    var groups: [MWGroupDTO1]
    var devices: [MWMetadataDTO1]
    init(model: MWKnownDevicesLoadable) {
        self.groups = model.groups.map(MWGroupDTO1.init(model:))
        self.devices = model.devices.map(MWMetadataDTO1.init(model:))
    }
    func asModel() -> MWKnownDevicesLoadable {
        .init(groups: groups.map(\.model), devices: devices.map(\.appModel))
    }
}

fileprivate struct MWGroupDTO1: Codable {
    let id: UUID
    var deviceMACs: Set<String>
    var name: String
    init(model: MetaWear.Group) {
        self.id = model.id
        self.deviceMACs = model.deviceMACs
        self.name = model.name
    }
    var model: MetaWear.Group {
        .init(id: id, deviceMACs: deviceMACs, name: name)
    }
}

fileprivate struct MWMetadataDTO1: Codable {
    var mac: String
    var serial: String
    var model: MWMetadataModelDTO1
    var modules: [MWModulesDTO1]

    var localBluetoothIds: Set<UUID>
    var name: String

    init(model: MetaWear.Metadata) {
        self.mac = model.mac
        self.model = .init(model: model.model)
        self.serial = model.serial
        self.modules = model.modules.map(\.value).map(MWModulesDTO1.init)
        self.localBluetoothIds = model.localBluetoothIds
        self.name = model.name
    }

    var appModel: MetaWear.Metadata {
        return .init(
            mac: mac,
            serial: serial,
            model: model.model,
            modules: modules.map(\.model).dictionary(),
            localBluetoothIds: localBluetoothIds,
            name: name
        )
    }
}

fileprivate enum MWMetadataModelDTO1: Codable {
    case unknown, wearR, wearRG, wearRPRO, wearC, wearCPRO, environment, detector, health, tracker, motionR, motionRL, motionC, motionS

    init(model: MetaWear.Model) {
        switch model {
            case .wearR: self = .wearR
            case .wearRG: self = .wearRG
            case .wearRPRO: self = .wearRPRO
            case .wearC: self = .wearC
            case .wearCPRO: self = .wearCPRO
            case .environment: self = .environment
            case .detector: self = .detector
            case .health: self = .health
            case .tracker: self = .tracker
            case .motionR: self = .motionR
            case .motionRL: self = .motionRL
            case .motionC: self = .motionC
            case .motionS: self = .motionS
            default: self = .unknown
        }
    }

    var model: MetaWear.Model {
        switch self {
            case .wearR: return .wearR
            case .wearRG: return .wearRG
            case .wearRPRO: return .wearRPRO
            case .wearC: return .wearC
            case .wearCPRO: return .wearCPRO
            case .environment: return .environment
            case .detector: return .detector
            case .health: return .health
            case .tracker: return .tracker
            case .motionR: return .motionR
            case .motionRL: return .motionRL
            case .motionC: return .motionC
            case .motionS: return .motionS
            default: return .unknown
        }
    }
}

fileprivate enum MWModulesDTO1: Codable {

    case barometer(Barometer)
    case accelerometer(Accelerometer)
    case gyroscope(Gyroscope)
    case magnetometer
    case humidity
    case illuminance
    case thermometer([Thermometer])
    case sensorFusion

    init(model: MWModules) {
        switch model {
            case .barometer(let model): self = .barometer(.init(model: model))
            case .accelerometer(let model): self = .accelerometer(.init(model: model))
            case .gyroscope(let model): self = .gyroscope(.init(model: model))
            case .magnetometer: self = .magnetometer
            case .humidity: self = .humidity
            case .illuminance: self = .illuminance
            case .thermometer(let models): self = .thermometer(models.map(MWModulesDTO1.Thermometer.init(model:)))
            case .sensorFusion: self = .sensorFusion
        }
    }

    var model: MWModules {
        switch self {
            case .barometer(let model): return .barometer(model.model)
            case .accelerometer(let model): return .accelerometer(model.model)
            case .gyroscope(let model): return .gyroscope(model.model)
            case .magnetometer: return .magnetometer
            case .humidity: return .humidity
            case .illuminance: return .illuminance
            case .thermometer(let models): return .thermometer(models.map(\.model))
            case .sensorFusion: return .sensorFusion
        }
    }

    enum Barometer: Codable {
        case bmp280
        case bme280
        init(model: MWBarometer.Model) {
            switch model {
                case .bme280: self = .bme280
                case .bmp280: self = .bmp280
            }
        }
        var model: MWBarometer.Model {
            switch self {
                case .bme280: return .bme280
                case .bmp280: return .bmp280
            }
        }
    }
    enum Accelerometer: Codable {
        case bmi160
        case bmi270
        case bma255
        init(model: MWAccelerometer.Model) {
            switch model {
                case .bmi160: self = .bmi160
                case .bmi270: self = .bmi270
                case .bma255: self = .bma255
            }
        }
        var model: MWAccelerometer.Model {
            switch self {
                case .bmi160: return .bmi160
                case .bmi270: return .bmi270
                case .bma255: return .bma255
            }
        }
    }
    enum Gyroscope: Codable {
        case bmi270
        case bmi160
        init(model: MWGyroscope.Model) {
            switch model {
                case .bmi270: self = .bmi270
                case .bmi160: self = .bmi160
            }
        }
        var model: MWGyroscope.Model {
            switch self {
                case .bmi270: return .bmi270
                case .bmi160: return .bmi160
            }
        }
    }
    enum Thermometer: Codable {
        case onDie
        case external
        case bmp280
        case onboard
        case custom
        init(model: MWThermometer.Source) {
            switch model {
                case .onDie: self = .onDie
                case .external: self = .external
                case .bmp280: self = .bmp280
                case .onboard: self = .onboard
                case .custom: self = .custom
            }
        }
        var model: MWThermometer.Source {
            switch self {
                case .onDie: return .onDie
                case .external: return .external
                case .bmp280: return .bmp280
                case .onboard: return .onboard
                case .custom: return .custom
            }
        }
    }
}
