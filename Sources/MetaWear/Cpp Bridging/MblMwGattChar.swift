// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import MetaWearCpp


/// Helpers for dealing with the C++ version of GATT Service/Characteristic
extension MblMwGattChar: Hashable {

    var serviceUUID: CBUUID { CBUUID(high64: service_uuid_high, low64: service_uuid_low) }

    var characteristicUUID: CBUUID { CBUUID(high64: uuid_high, low64: uuid_low) }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(service_uuid_high)
        hasher.combine(service_uuid_low)
        hasher.combine(uuid_high)
        hasher.combine(uuid_low)
    }

    public static func ==(lhs: MblMwGattChar, rhs: MblMwGattChar) -> Bool {
        return lhs.service_uuid_high == rhs.service_uuid_high &&
            lhs.service_uuid_low == rhs.service_uuid_low &&
            lhs.uuid_high == rhs.uuid_high &&
            lhs.uuid_low == rhs.uuid_low
    }
}

extension CBUUID {

    convenience init(high64: UInt64, low64: UInt64) {
        let uuid_high_swap = high64.byteSwapped
        let uuid_low_swap  = low64.byteSwapped
        var data = withUnsafePointer(to: uuid_high_swap) { p in
            Data(buffer: UnsafeBufferPointer(start: p, count: 1))
        }
        withUnsafePointer(to: uuid_low_swap) { p in
            data.append(UnsafeBufferPointer(start: p, count: 1))
        }
        self.init(data: data)
    }
}
