// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

/// Versioning container to save and migrate MetaWear Metadata across SDK versions
///
public struct MWKnownDevicesContainer: Codable, MWVersioningContainer {
    fileprivate typealias DTO = MWKnownDevicesLoadableDTO1
    public typealias Loadable = MWKnownDevicesLoadable
    public var versionSentinel = 1
    public var data: Data = .init()

    public init(data: Data, decoder: JSONDecoder) throws {
        guard data.isEmpty == false else { return }
        self = try decoder.decode(Self.self, from: data)
    }

    public func load(_ decoder: JSONDecoder) throws -> Loadable {
        guard data.isEmpty == false else { return .init() }
        guard versionSentinel == 1 else { throw CocoaError(.coderValueNotFound) }
        return try decoder.decode(DTO.self, from: data).asModel()
    }

    public static func encode(_ loadable: Loadable, _ encoder: JSONEncoder) throws -> Data {
        let container = try Self.init(loadable: loadable, encoder: encoder)
        return try encoder.encode(container)
    }

    private init(loadable: Loadable, encoder: JSONEncoder) throws {
        let dto = DTO(model: loadable)
        self.data = try encoder.encode(dto)
    }

}

fileprivate struct MWKnownDevicesLoadableDTO1: Codable {
    var devices: [MWMetadataDTO1]
    var groups: [MWGroupDTO1]
    var groupsRecovery: [MWGroupDTO1]
    init(model: MWKnownDevicesLoadable) {
        self.groups = model.groups.map(MWGroupDTO1.init(model:))
        self.devices = model.devices.map(MWMetadataDTO1.init(model:))
        self.groupsRecovery = model.groupsRecovery.map(MWGroupDTO1.init(model:))
    }
    func asModel() -> MWKnownDevicesLoadable {
        .init(devices: devices.map(\.appModel),
              groups: groups.map(\.model),
              groupsRecovery: groupsRecovery.map(\.model))
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

    case mechanicalSwitch
    case led
    case gpio
    case iBeacon
    case haptic
    case i2c

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

            case .mechanicalSwitch: self = .mechanicalSwitch
            case .led: self = .led
            case .gpio: self = .gpio
            case .iBeacon: self = .iBeacon
            case .haptic: self = .haptic
            case .i2c: self = .i2c
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

            case .mechanicalSwitch: return .mechanicalSwitch
            case .led: return .led
            case .gpio: return .gpio
            case .iBeacon: return .iBeacon
            case .haptic: return .haptic
            case .i2c: return .i2c
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
