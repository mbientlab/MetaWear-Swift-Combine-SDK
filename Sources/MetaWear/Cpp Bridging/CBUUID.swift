// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import Combine

// MARK: - Type safe encapsulation

public extension MetaWear.ServiceCharacteristic where DataType == UInt8 {

    /// Values: 0 to 100
    static let batteryLife = MetaWear.ServiceCharacteristic("Battery Life", .battery, .batteryLife, parse: Self.toUInt8)

    private static func toUInt8(_ data: Data) -> UInt8 {
        [UInt8](data).first ?? 0
    }
}

public extension MetaWear.ServiceCharacteristic where DataType == String {

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

public extension MetaWear.ServiceCharacteristic where DataType == MetaWear.DeviceInformation {

    /// The board's manufacturer, hardware version, firmware version, serial number, and model number.
    ///
    static let allDeviceInformation = MetaWear.ServiceCharacteristic("Device Information", .dis, .manufacturerName, parse: Self.handleSeparately)

    private static func handleSeparately(_ data: Data) -> MetaWear.DeviceInformation {
        fatalError()
    }
}

public extension MetaWear {
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

    static let Notification = CBUUID(string: "326A9006-85CB-9195-D9DD-464CFBBAE75A")
    static let Command      = CBUUID(string: "326A9001-85CB-9195-D9DD-464CFBBAE75A")

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

// MARK: - Internal Utility

internal extension MetaWear.DeviceInformation {

    static func publisher(for device: MetaWear) -> MWPublisher<MetaWear.DeviceInformation> {
        Publishers.Zip(device.readCharacteristic(.manufacturerName), device.readCharacteristic(.modelNumber))
            .zip(device.readCharacteristic(.serialNumber),
                 device.readCharacteristic(.firmwareRevision),
                 device.readCharacteristic(.hardwareRevision), { mm, serial, firm, hard in
                (mm.0, mm.1, serial, firm, hard)
            })
            .map(MetaWear.DeviceInformation.init)
            .eraseToAnyPublisher()
    }
}
