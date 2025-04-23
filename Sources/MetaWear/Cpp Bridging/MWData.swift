// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

///
/// This holds data from the MetaWear
///
enum MblMwDataTypeId: UInt8 {
    case MBL_MW_DT_ID_UINT32 = 0            ///< Data is an unsigned integer
    case MBL_MW_DT_ID_FLOAT                 ///< Data is a float
    case MBL_MW_DT_ID_CARTESIAN_FLOAT       ///< Data is a CartesianFloat
    case MBL_MW_DT_ID_INT32                 ///< Data is a signed integer
    case MBL_MW_DT_ID_BYTE_ARRAY            ///< Data is a byte array
    case MBL_MW_DT_ID_BATTERY_STATE         ///< Data is a BatteryState
    case MBL_MW_DT_ID_TCS34725_ADC          ///< Data is a Tcs34725ColorAdc
    case MBL_MW_DT_ID_EULER_ANGLE
    case MBL_MW_DT_ID_QUATERNION
    case MBL_MW_DT_ID_CORRECTED_CARTESIAN_FLOAT
    case MBL_MW_DT_ID_OVERFLOW_STATE
    case MBL_MW_DT_ID_SENSOR_ORIENTATION
    case MBL_MW_DT_ID_STRING
    case MBL_MW_DT_ID_LOGGING_TIME
    case MBL_MW_DT_ID_BTLE_ADDRESS
    case MBL_MW_DT_ID_BOSCH_ANY_MOTION
    case MBL_MW_DT_ID_CALIBRATION_STATE
    case MBL_MW_DT_ID_DATA_ARRAY
    case MBL_MW_DT_ID_BOSCH_TAP
    case MBL_MW_DT_ID_BOSCH_GESTURE
}

typealias Claim<T> = (type: T.Type, typeId: MblMwDataTypeId)

public struct MWData {
    
    /// MetaWears "tick" to track time, but lack any sort of calendar. This is a directly translated "tick" date into the local time.
    ///
    public let timestamp: Date
    
    /// Raw data of the type specified in ``typeId``.
    let data: Data
    
    /// Raw data type for the bytes in the ``data`` array.
    let typeId: MblMwDataTypeId
    
    /// Generic function that casts some Data object into a type T
    public func valueAs<T>() -> T {
        return castAs((T.self, typeId), data)
    }
    
    func castAs<T>(_ target: Claim<T>, _ data: Data) -> T {
        print("castAs called with target: \(target) and data size: \(data.count)")

        switch (data[0], data[1]) {
        case (0x11, 0x8B):
            print("MAC Address")
            return data.dropFirst(3).map { String(format: "%02X", $0) }.joined(separator: ":") as! T
        case (0x01, 0x81):
            print("Button Switch")
            return UInt32(data[2]) as! T
        case (let first, let second):
            print("Default case: First byte is \(first), second byte is \(second)")
        }
        
        if isByteArray(target) {
            guard let byteArray = Array(data) as? T else {
                fatalError("Failed to cast data to byte array.")
            }
            return byteArray
        }
        
        if isString(target) {
            if let string = String(data: data, encoding: .ascii) {
                guard let castedString = string as? T else {
                    fatalError("Failed to cast decoded string to type \(T.self).")
                }
                return castedString
            } else {
                // Fallback: Represent as a hexadecimal string
                let hexString = data.map { String(format: "%02X", $0) }.joined(separator: ":")
                guard let castedHexString = hexString as? T else {
                    fatalError("Failed to cast hexadecimal representation to type \(T.self).")
                }
                return castedHexString
            }
        }
        
        if isDataArray(target) {
            guard let dataArray = Array(data) as? T else {
                fatalError("Failed to cast data to data array.")
            }
            return dataArray
        }
        assertMatching(target)
        guard let castedData = data as? T else {
            fatalError("Failed to cast data to target type.")
        }
        return castedData
    }

}

fileprivate func isString<T>(_ input: Claim<T>) -> Bool {
    guard input.typeId == MblMwDataTypeId.MBL_MW_DT_ID_STRING else { return false }
    assert(T.self == String.self || T.self == String?.self)
    return true
}

fileprivate func isByteArray<T>(_ input: Claim<T>) -> Bool {
    guard input.typeId == MblMwDataTypeId.MBL_MW_DT_ID_BYTE_ARRAY else { return false }
    assert(T.self == [UInt8].self)
    return true
}

fileprivate func isDataArray<T>(_ input: Claim<T>) -> Bool {
    guard input.typeId == MblMwDataTypeId.MBL_MW_DT_ID_DATA_ARRAY else { return false }
    return true
}

fileprivate func assertMatching<T>(_ input: Claim<T>) {
    switch input.typeId {
    case MblMwDataTypeId.MBL_MW_DT_ID_UINT32:                    assert(T.self == UInt32.self)                       // 0
    case MblMwDataTypeId.MBL_MW_DT_ID_FLOAT:                     assert(T.self == Float.self)                        // 1
    //case MblMwDataTypeId.MBL_MW_DT_ID_CARTESIAN_FLOAT:           assert(T.self == MblMwCartesianFloat.self)          // 2
    case MblMwDataTypeId.MBL_MW_DT_ID_INT32:                     assert(T.self == Int32.self)                        // 3
            // BYTE_ARRAY 4
    //case MblMwDataTypeId.MBL_MW_DT_ID_BATTERY_STATE:             assert(T.self == MblMwBatteryState.self)            // 5
    //case MblMwDataTypeId.MBL_MW_DT_ID_TCS34725_ADC:              assert(T.self == MblMwTcs34725ColorAdc.self)        // 6
    //case MblMwDataTypeId.MBL_MW_DT_ID_EULER_ANGLE:               assert(T.self == MblMwEulerAngles.self)             // 7
    //case MblMwDataTypeId.MBL_MW_DT_ID_QUATERNION:                assert(T.self == MblMwQuaternion.self)              // 8
    //case MblMwDataTypeId.MBL_MW_DT_ID_CORRECTED_CARTESIAN_FLOAT: assert(T.self == MblMwCorrectedCartesianFloat.self) // 9
    //case MblMwDataTypeId.MBL_MW_DT_ID_OVERFLOW_STATE:            assert(T.self == MblMwOverflowState.self)           // 10
    //case MblMwDataTypeId.MBL_MW_DT_ID_SENSOR_ORIENTATION:        assert(T.self == MblMwSensorOrientation.self)       // 11
            // STRING 12
    //case MblMwDataTypeId.MBL_MW_DT_ID_LOGGING_TIME:              assert(T.self == MblMwLoggingTime.self)             // 13
    //case MblMwDataTypeId.MBL_MW_DT_ID_BTLE_ADDRESS:              assert(T.self == MblMwBtleAddress.self)             // 14
    //case MblMwDataTypeId.MBL_MW_DT_ID_BOSCH_ANY_MOTION:          assert(T.self == MblMwBoschAnyMotion.self)          // 15
    //case MblMwDataTypeId.MBL_MW_DT_ID_CALIBRATION_STATE:         assert(T.self == MblMwCalibrationState.self)        // 16
            // DATA_ARRAY 17
    //case MblMwDataTypeId.MBL_MW_DT_ID_BOSCH_TAP:                 assert(T.self == MblMwBoschTap.self)                // 18
    //case MblMwDataTypeId.MBL_MW_DT_ID_BOSCH_GESTURE:             assert(T.self == MblMwBoschGestureType.self)        // 19
        default: fatalError("unknown data type")
    }
}
