// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import MetaWearCpp

/// Useful when interacting with the C++ library.
///
/// This holds data from the MetaWear because the
/// C++ library destroys `MblMwData` objects after
/// a callback.
///
public struct MWData {
    public let timestamp: Date
    let data: Array<UInt8>
    let typeId: MblMwDataTypeId

    public func valueAs<T>() -> T {
        data.withUnsafeBytes { p in
            castAs((T.self, typeId), p)
        }
    }
}

// MARK: - Log Wrapper

public extension MWData {

    struct LogDownload {
        public let logger: MWLogger
        public let data: [MWData]

        public init(logger: MWLogger, data: [MWData]) {
            self.logger = logger
            self.data = data
        }
    }
}

// MARK: - Move from C++

extension MblMwData {
    public func copy() -> MWData {
        let arrayPtr = value.bindMemory(to: UInt8.self, capacity: Int(length))
        return MWData(timestamp: timestamp,
                      data: .init(UnsafeBufferPointer(start: arrayPtr, count: Int(length))),
                      typeId: type_id)
    }
    public var timestamp: Date {
        let date = Date(timeIntervalSince1970: Double(epoch) / 1000.0)
        let milliseconds = epoch%1000
        return Calendar.current.date(byAdding: .nanosecond, value: Int(milliseconds), to: date)!
    }

    public func valueAs<T>() -> T {
        let b = UnsafeRawBufferPointer(start: value, count: .init(length))
        return castAs((T.self, type_id), b)
    }

    public func extraAs<T>() -> T {
        return extra.bindMemory(to: T.self, capacity: 1).pointee
    }
}

// MARK: - Cast

func castAs<T>(_ target: Claim<T>, _ pointer: UnsafeRawBufferPointer) -> T {
    if isByteArray(target) {
        return Array(pointer) as! T
    }
    if isString(target), let typed = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) {
        return String(cString: typed) as! T
    }
    if isDataArray(target) {
        let buffer = pointer.bindMemory(to: T.self)
        return Array(buffer) as! T
    }

    assert(MemoryLayout<T>.size == pointer.endIndex)
    assertMatching(target)
    return pointer.load(as: T.self)
}

typealias Claim<T> = (type: T.Type, typeId: MblMwDataTypeId)

fileprivate func isString<T>(_ input: Claim<T>) -> Bool {
    guard input.typeId == MBL_MW_DT_ID_STRING else { return false }
    assert(T.self == String.self || T.self == String?.self)
    return true
}

fileprivate func isByteArray<T>(_ input: Claim<T>) -> Bool {
    guard input.typeId == MBL_MW_DT_ID_BYTE_ARRAY else { return false }
    assert(T.self == [UInt8].self)
    return true
}

fileprivate func isDataArray<T>(_ input: Claim<T>) -> Bool {
    guard input.typeId == MBL_MW_DT_ID_DATA_ARRAY else { return false }
    assert(T.self == [MblMwData].self)
    return true
}

fileprivate func assertMatching<T>(_ input: Claim<T>) {
    switch input.typeId {
        case MBL_MW_DT_ID_UINT32:                    assert(T.self == UInt32.self)
        case MBL_MW_DT_ID_FLOAT:                     assert(T.self == Float.self)
        case MBL_MW_DT_ID_CARTESIAN_FLOAT:           assert(T.self == MblMwCartesianFloat.self)
        case MBL_MW_DT_ID_INT32:                     assert(T.self == Int32.self)
        case MBL_MW_DT_ID_BATTERY_STATE:             assert(T.self == MblMwBatteryState.self)
        case MBL_MW_DT_ID_TCS34725_ADC:              assert(T.self == MblMwTcs34725ColorAdc.self)
        case MBL_MW_DT_ID_EULER_ANGLE:               assert(T.self == MblMwEulerAngles.self)
        case MBL_MW_DT_ID_QUATERNION:                assert(T.self == MblMwQuaternion.self)
        case MBL_MW_DT_ID_CORRECTED_CARTESIAN_FLOAT: assert(T.self == MblMwCorrectedCartesianFloat.self)
        case MBL_MW_DT_ID_OVERFLOW_STATE:            assert(T.self == MblMwOverflowState.self)
        case MBL_MW_DT_ID_SENSOR_ORIENTATION:        assert(T.self == MblMwSensorOrientation.self)
        case MBL_MW_DT_ID_LOGGING_TIME:              assert(T.self == MblMwLoggingTime.self)
        case MBL_MW_DT_ID_BTLE_ADDRESS:              assert(T.self == MblMwBtleAddress.self)
        case MBL_MW_DT_ID_BOSCH_ANY_MOTION:          assert(T.self == MblMwBoschAnyMotion.self)
        case MBL_MW_DT_ID_BOSCH_GESTURE:             assert(T.self == MblMwBoschGestureType.self)
        case MBL_MW_DT_ID_CALIBRATION_STATE:         assert(T.self == MblMwCalibrationState.self)
        case MBL_MW_DT_ID_BOSCH_TAP:                 assert(T.self == MblMwBoschTap.self)
        default: fatalError("unknown data type")
    }
}
