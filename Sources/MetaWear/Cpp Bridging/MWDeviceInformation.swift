// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import MetaWearCpp
import Combine

// MARK: - Public API

public extension MetaWear {

    /// Details about a MetaWear's hardware and firmware.
    ///
    struct DeviceInformation {
        public let manufacturer: String
        public var model: Model
        public let serialNumber: String
        public let firmwareRevision: String
        public let hardwareRevision: String
        public var mac: String

        public init(manufacturer: String,
                    model: Model,
                    serialNumber: String,
                    firmwareRevision: String,
                    hardwareRevision: String,
                    mac: String
        ) {
            self.manufacturer = manufacturer
            self.model = model
            self.serialNumber = serialNumber
            self.firmwareRevision = firmwareRevision
            self.hardwareRevision = hardwareRevision
            self.mac = mac
        }
    }
}

// MARK: - Public Publisher API

extension MetaWear.DeviceInformation: MWReadableMerged {

    public typealias DataType = MetaWear.DeviceInformation

    public func read(from device: MetaWear) -> MWPublisher<MetaWear.DeviceInformation> {
        Publishers.Zip3(
            device._read(.manufacturerName),
            _JustMW(Self.getModel(board: device.board)),
            device.publish().read(.macAddress).map(\.value)
        )
            .zip(device._read(.serialNumber),
                 device._read(.firmwareRevision),
                 device._read(.hardwareRevision),
                 { mmm, serial, firm, hard in
                (mmm.0, mmm.1, serial, firm, hard, mmm.2)
            })
            .map(MetaWear.DeviceInformation.init)
            .eraseToAnyPublisher()
    }

    static func getModel(board: MWBoard) -> MetaWear.Model {
        let number = mbl_mw_metawearboard_get_model(board)
        return .init(modelNumber: number)
    }
}

public extension MWReadableMerged where Self == MetaWear.DeviceInformation {
    static var deviceInformation: Self { Self(mac: "") }
}

// MARK: - Internal Utility

extension MetaWear.DeviceInformation {
    /// For CBPeripheral->MetaWear initialization only using UserDefaults and before board setup
    internal init(mac: String?) {
        self.manufacturer = ""
        self.model = .unknown
        self.serialNumber = ""
        self.firmwareRevision = ""
        self.hardwareRevision = ""
        self.mac = mac ?? ""
    }
}

extension MblMwDeviceInformation {

    /// Used to bridge between MetaWearCpp classes and native managed Swift struct.
    /// A synchronous function to get the model is called, discarding the C struct's model name.
    /// The MAC address must be acquired separately.
    ///
    func convert(for board: MWBoard, mac: String) -> MetaWear.DeviceInformation {
        MetaWear.DeviceInformation(
            manufacturer: String(cString: manufacturer),
            model: MetaWear.DeviceInformation.getModel(board: board),
            serialNumber: String(cString: serial_number),
            firmwareRevision: String(cString: firmware_revision),
            hardwareRevision: String(cString: hardware_revision),
            mac: mac
        )
    }
}
