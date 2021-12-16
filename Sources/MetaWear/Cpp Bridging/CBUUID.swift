// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import Combine
import MetaWearCpp


// MARK: - CBUUID

/// Bluetooth ID's used by MetaWear
public extension CBUUID {
    static let metaWearService       = CBUUID(string: "326A9000-85CB-9195-D9DD-464CFBBAE75A")
    static let metaWearCommand       = CBUUID(string: "326A9001-85CB-9195-D9DD-464CFBBAE75A")
    static let metaWearNotification  = CBUUID(string: "326A9006-85CB-9195-D9DD-464CFBBAE75A")
    static let metaWearDfuService    = CBUUID(string: "00001530-1212-EFDE-1523-785FEABCD123")
    static let batteryService        = CBUUID(string: "180F")
    static let batteryLife           = CBUUID(string: "2A19")
    static let disService            = CBUUID(string: "180A")
    static let disModelNumber        = CBUUID(string: "2A24")
    static let disSerialNumber       = CBUUID(string: "2A25")
    static let disFirmwareRev        = CBUUID(string: "2A26")
    static let disHardwareRev        = CBUUID(string: "2A27")
    static let disManufacturerName   = CBUUID(string: "2A29")
}

public extension MetaWear {

    enum Service {
        case metaWear
        case dfu
        case battery
        case dis

        public var cbuuid: CBUUID {
            switch self {
                case .metaWear: return CBUUID(string: "326A9000-85CB-9195-D9DD-464CFBBAE75A")
                case .dfu:      return CBUUID(string: "00001530-1212-EFDE-1523-785FEABCD123")
                case .battery:  return CBUUID(string: "180F")
                case .dis:      return CBUUID(string: "180A")
            }
        }
    }

    enum Characteristic: String, CaseIterable {
        case manufacturerName
        case hardwareRevision
        case firmwareRevision
        case serialNumber
        case batteryLife
        case modelNumber

        init?(cbuuid: CBUUID) {
            guard let c = Self.allCases.first(where: { $0.cbuuid == cbuuid }) else { return nil }
            self = c
        }

        public var cbuuid: CBUUID {
            switch self {
                case .manufacturerName: return CBUUID(string: "2A29")
                case .hardwareRevision: return CBUUID(string: "2A27")
                case .firmwareRevision: return CBUUID(string: "2A26")
                case .serialNumber:     return CBUUID(string: "2A25")
                case .batteryLife:      return CBUUID(string: "2A19")
                case .modelNumber:      return CBUUID(string: "2A24")
            }
        }

        public var service: Service {
            switch self {
                case .manufacturerName: return .dis
                case .modelNumber:      return .dis
                case .hardwareRevision: return .dis
                case .firmwareRevision: return .dis
                case .serialNumber:     return .dis
                case .batteryLife:      return .battery
            }
        }
    }
}

// MARK: - Internal Publishers

internal extension MetaWear {

    /// Requests refreshed information about this MetaWear, such as its battery percentage, serial number, model, manufacturer, and hardware and firmware versions.
    func _read<T>(_ characteristic: MetaWear.ServiceCharacteristic<T>) -> MWPublisher<T> {
        _read(service: characteristic.service.cbuuid, characteristic: characteristic.characteristic.cbuuid)
            .map { characteristic.parse($0) }
            .eraseToAnyPublisher()
    }

    /// Request a refreshed value for the target service and characteristic.
    func _read(service: CBUUID, characteristic: CBUUID) -> MWPublisher<Data> {
        _getCharacteristic(service, characteristic)
            .publisher
            .flatMap { [weak self] characteristic -> AnyPublisher<Data,MWError> in
                let subject = PassthroughSubject<Data, MWError>()
                self?._readCharacteristicSubjects[characteristic, default: []].append(subject)
                self?.peripheral.readValue(for: characteristic)
                return subject.eraseToAnyPublisher()
            }
            .erase(subscribeOn: bleQueue)
    }

    /// Synchronously lookup CBService and CBCharacteristics.
    func _getCharacteristic(_ serviceUUID: CBUUID,_ characteristicUUID: CBUUID) -> Result<CBCharacteristic, MWError> {
        guard let service = self.peripheral.services?.first(where: { $0.uuid == serviceUUID })
        else { return .failure(.operationFailed("Service not found")) }

        guard let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID })
        else { return .failure(.operationFailed("Characteristics not found")) }

        return .success(characteristic)
    }
}



// MARK: - Type safe encapsulation

internal extension MetaWear.ServiceCharacteristic where DataType == UInt8 {

    /// Values: 0 to 100
    static let batteryLife = MetaWear.ServiceCharacteristic("Battery Life", .battery, .batteryLife, parse: Self.toUInt8)

    private static func toUInt8(_ data: Data) -> UInt8 {
        [UInt8](data).first ?? 0
    }
}

internal extension MetaWear.ServiceCharacteristic where DataType == String {

    /// The board's manufacturer.
    static let manufacturerName = MetaWear.ServiceCharacteristic("Manufacturer Name", .dis, .manufacturerName, parse: Self.toString)

    /// The board's hardware version.
    static let hardwareRevision = MetaWear.ServiceCharacteristic("Hardware Revision", .dis, .hardwareRevision, parse: Self.toString)

    /// The board's firmware version.
    static let firmwareRevision = MetaWear.ServiceCharacteristic("Firmware Revision", .dis, .firmwareRevision, parse: Self.toString)

    /// The board's model number.
    static let modelNumber = MetaWear.ServiceCharacteristic("Model Number", .dis, .modelNumber, parse: Self.toString)

    /// The board's serial number.
    static let serialNumber = MetaWear.ServiceCharacteristic("Serial Number", .dis, .serialNumber, parse: Self.toString)

    private static func toString(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }
}

internal extension MetaWear {
    /// Defines a response for a Characteristic and Service combo
    ///
    struct ServiceCharacteristic<DataType> {

        /// Used for error messages
        public let name: String
        public let service: MetaWear.Service
        public let characteristic: MetaWear.Characteristic
        public var parse: (Data) -> DataType

        internal init(_ name: String, _ service: MetaWear.Service, _ characteristic: MetaWear.Characteristic, parse: @escaping (Data) -> DataType) {
            self.name = name
            self.service = service
            self.characteristic = characteristic
            self.parse = parse
        }
    }
}
