// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp
import simd

// MARK: - Type Safe Data Conversions

/// Has a defined conversion from a `MblMwData` C++ struct into a
/// defined Swift value type whose lifetime is not confined to the C++ closure.
public protocol MWDataConvertible: Equatable & Hashable {

    /// Final converted Swift value type
    associatedtype DataType

    /// MetaWear Cpp data type specified in`MblMwData`
    associatedtype RawDataType

    /// Converts the Cpp value type to a
    /// convenient Swift type
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType>

    /// Converts `MblMwData` to a concretely
    /// typed timestamped tuple
    func convert(raw: MWData) -> Timestamped<RawDataType>

    /// Convert DataType to String columns, with [0] being the `timeIntervalSince1970`
    func asColumns(_ datum: Timestamped<DataType>) -> [String]

    var columnHeadings: [String] { get }

}

// MARK: - Internal (General Default Implementations)

public extension MWDataConvertible {

    func convert(raw: MWData) -> Timestamped<RawDataType> {
        (time: raw.timestamp, raw.valueAs() as RawDataType)
    }

    func convertRawToSwift(_ raw: MWData) -> Timestamped<DataType> {
        convert(from: convert(raw: raw))
    }

    func convertRawToColumns(_ raw: MWData) -> [String] {
        asColumns(convertRawToSwift(raw))
    }

    /// Useful for error messages
    var name: String { "\(Self.self)" }
}

public extension MWDataConvertible where RawDataType == DataType {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        raw
    }
}

// MARK: - Internal (Accelerometer)

public extension MWDataConvertible where
RawDataType == MblMwSensorOrientation,
DataType    == MWAccelerometer.Orientation {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(sensor: raw.value)!)
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, datum.value.rawValue]
    }

    var columnHeadings: [String] { ["Epoch", "Orientation"] }
}

public extension MWDataConvertible where
RawDataType == MblMwCartesianFloat,
DataType    == SIMD3<Float> {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(cartesian: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearEpochMS] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "X", "Y", "Z"] }
}

public extension MWDataConvertible where
RawDataType == MblMwQuaternion,
DataType    == SIMD4<Float> {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(quaternion: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearEpochMS] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "X", "Y", "Z", "W"] }
}

public extension MWDataConvertible where
RawDataType == MblMwQuaternion,
DataType    == simd_quatf {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(mblQuaternion: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearEpochMS] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "X", "Y", "Z", "W"] }
}

public extension MWDataConvertible where
RawDataType == MblMwEulerAngles,
DataType    == SIMD3<Float> {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(euler: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearEpochMS] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "X", "Y", "Z"] }
}

public extension MWDataConvertible where
RawDataType == MblMwBoschAnyMotion,
DataType    == MWMotion.Activity.AnyMotionTrigger {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(raw: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearEpochMS] + datum.value.stringify()
    }
}

public extension MWDataConvertible where
RawDataType == MblMwAccBoschActivity,
DataType    == MWMotion.Activity.Classification {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(cppValue: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, datum.value.label]
    }
}

public extension MWDataConvertible where
RawDataType == UInt32,
DataType    == MWChargingStatus.State {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(value: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, datum.value.label]
    }
}

public extension MWDataConvertible where
RawDataType == UInt32,
DataType    == MWMechanicalButton.State {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(value: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, datum.value.label]
    }
}

public extension MWDataConvertible where
RawDataType == MblMwLoggingTime,
DataType    == (time: Date, resetID: UInt8) {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, (Date(timeIntervalSinceReferenceDate: Double(raw.value.epoch) / 1000), raw.value.reset_uid) )
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, String(datum.value.time.timeIntervalSinceReferenceDate)]
    }
}

public extension MWDataConvertible where
RawDataType == UInt8,
DataType    == Int {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(raw.value))
    }
}

public extension MWDataConvertible where
RawDataType == Int32,
DataType    == Int {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(raw.value))
    }
}

public extension MWDataConvertible where
RawDataType == UInt32,
DataType    == Int {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(raw.value))
    }
}

public extension MWDataConvertible where
RawDataType == MblMwBatteryState,
DataType    == Int {

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, Int(raw.value.charge))
    }
}

// MARK: - Data Type Conversions

public extension MWDataConvertible where DataType == Int {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Int32 {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Int8 {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Double {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Float {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == String {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearEpochMS, datum.value]
    }
}

// MARK: - Vector Utilities

public extension SIMD3 where Scalar == Float {
    init(cartesian c: MblMwCartesianFloat) {
        self.init(x: c.x, y: c.y, z: c.z)
    }

    init(euler e: MblMwEulerAngles) {
        self.init(e.pitch, e.roll, e.yaw)
    }
}

public extension SIMD4 where Scalar == Float {
    init(quaternion q: MblMwQuaternion) {
        self.init(x: q.x, y: q.y, z: q.z, w: q.w)
    }
}

public extension simd_quatf {
    init(mblQuaternion raw: MblMwQuaternion) {
        self.init(ix: raw.x, iy: raw.y, iz: raw.z, r: raw.w)
    }
}


// MARK: - String Utilities

public extension SIMD3 where Scalar == Float {
    func stringify() -> [String] {
        self.indices.reduce(into: [String]()) { string, index in
            string.append(.init(mwDecimals: self[index]))
        }
    }
}

public extension SIMD4 where Scalar == Float {
    func stringify() -> [String] {
        self.indices.reduce(into: [String]()) { string, index in
            string.append(.init(mwDecimals: self[index]))
        }
    }
}

public extension simd_quatf {
    func stringify() -> [String] {
        let vector = self.vector
        return vector.indices.map { String(mwDecimals: vector[$0]) }
    }
}


public extension String {
    init(mwDecimals: CVarArg) {
        self.init(format: "%1.\(MWDataTable.stringDecimalDigits)f", mwDecimals)
    }

    init(int: Double) {
        self.init( Int(int) )
    }

    init(mwPercent: Double) {
        self = "\(Int(mwPercent * 100))%"
    }
}

public extension Date {

    /// Time interval since 1970 (ms)
    ///
    var metaWearEpochMS: String {
        String(format: "%1.3f", timeIntervalSince1970)
    }
}
