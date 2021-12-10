// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import MetaWearCpp

public extension MetaWear {

    /// Container of information about a MetaWear board
    struct DeviceInformation {
        public let manufacturer: String
        public var model: Model
        public let serialNumber: String
        public let firmwareRevision: String
        public let hardwareRevision: String

        public init(manufacturer: String,
                    model: Model,
                    serialNumber: String,
                    firmwareRevision: String,
                    hardwareRevision: String) {
            self.manufacturer = manufacturer
            self.model = model
            self.serialNumber = serialNumber
            self.firmwareRevision = firmwareRevision
            self.hardwareRevision = hardwareRevision
        }
    }
}

extension MblMwDeviceInformation {
    /// Used to bridge between MetaWearCpp classes and native managed Swift struct. Actual model is not obtained.
    func convert(for device: MetaWear) -> MetaWear.DeviceInformation {
        return MetaWear.DeviceInformation(
            manufacturer: String(cString: manufacturer),
            model: MetaWear.DeviceInformation.getModel(device: device),
            serialNumber: String(cString: serial_number),
            firmwareRevision: String(cString: firmware_revision),
            hardwareRevision: String(cString: hardware_revision)
        )
    }
}
