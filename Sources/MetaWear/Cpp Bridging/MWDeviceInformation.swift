// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Combine

// MARK: - Public API

public extension MetaWear {

    /// Details about a MetaWear's hardware and firmware.
    ///
    struct DeviceInformation {
        public var manufacturer: String
        public var model: Model
        public var serialNumber: String
        public var firmwareRevision: String
        public var hardwareRevision: String
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
        if !mac.isEmpty {
            // Return a publisher that emits the current self as DeviceInformation
            return Just(
                MetaWear.DeviceInformation(
                    manufacturer: self.manufacturer,
                    model: self.model,
                    serialNumber: self.serialNumber,
                    firmwareRevision: self.firmwareRevision,
                    hardwareRevision: self.hardwareRevision,
                    mac: self.mac
                )
            )
            .setFailureType(to: MWError.self)
            .eraseToAnyPublisher()
        }

        // Perform the mac read if self.mac is empty
        return device.publish().read(.macAddress)
            .map { mac in
                MetaWear.DeviceInformation(
                    manufacturer: self.manufacturer,
                    model: self.model,
                    serialNumber: self.serialNumber,
                    firmwareRevision: self.firmwareRevision,
                    hardwareRevision: self.hardwareRevision,
                    mac: mac.value
                )
            }
            .eraseToAnyPublisher()
    }

    //static func turnToModel(model: String) -> MetaWear.Model {
    //    return .init(modelNumber: model)
    //}
    
    //static func getModel(board: MWBoard) -> MetaWear.Model {
        //let number = mbl_mw_metawearboard_get_model(board)
    //    let number = board.getModel()
    //    return .init(modelNumber: number)
    //}
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

//extension MblMwDeviceInformation {
//
//    /// Used to bridge between MetaWearCpp classes and native managed Swift struct.
//    /// A synchronous function to get the model is called, discarding the C struct's model name.
//    /// The MAC address must be acquired separately.
//    ///
//    func convert(for board: MWBoard, mac: String) -> MetaWear.DeviceInformation {
//        MetaWear.DeviceInformation(
//            manufacturer: String(cString: manufacturer),
//            model: MetaWear.DeviceInformation.getModel(board: board),
//            serialNumber: String(cString: serial_number),
//            firmwareRevision: String(cString: firmware_revision),
//            hardwareRevision: String(cString: hardware_revision),
//            mac: mac
//        )
//    }
//}
