// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import MetaWearCpp

public extension MetaWear {

    /// Container of information about a MetaWear board
    struct DeviceInformation {
        public let manufacturer: String
        public let modelNumber: String
        public let serialNumber: String
        public let firmwareRevision: String
        public let hardwareRevision: String

        public init(manufacturer: String,
                    modelNumber: String,
                    serialNumber: String,
                    firmwareRevision: String,
                    hardwareRevision: String) {
            self.manufacturer = manufacturer
            self.modelNumber = modelNumber
            self.serialNumber = serialNumber
            self.firmwareRevision = firmwareRevision
            self.hardwareRevision = hardwareRevision
        }
    }
}

extension MblMwDeviceInformation {
    /// Used to bridge between MetaWearCpp classes and native managed Swift struct
    func convert() -> MetaWear.DeviceInformation {
        return MetaWear.DeviceInformation(manufacturer: String(cString: manufacturer),
                                          modelNumber: String(cString: model_number),
                                          serialNumber: String(cString: serial_number),
                                          firmwareRevision: String(cString: firmware_revision),
                                          hardwareRevision: String(cString: hardware_revision))
    }
}
