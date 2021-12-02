// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

// MARK: - Type Safe Data Conversions

/// Has a defined conversion from
/// a `MblMwData` C++ struct into a
/// defined Swift value type whose lifetime
/// is not confined to the C++ closure.
public protocol MWDataConvertible {

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
DataType == MWAccelerometer.Orientation {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(sensor: raw.value)!)
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, datum.value.rawValue]
    }

    var columnHeadings: [String] { ["Epoch", "Orientation"] }
}

public extension MWDataConvertible where
RawDataType == MblMwCartesianFloat,
DataType == SIMD3<Float> {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(cartesian: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearCSVDate] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "X", "Y", "Z"] }
}

public extension MWDataConvertible where
RawDataType == MblMwQuaternion,
DataType == SIMD4<Float> {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(quaternion: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearCSVDate] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "X", "Y", "Z", "W"] }
}

public extension MWDataConvertible where
RawDataType == MblMwEulerAngles,
DataType == SIMD3<Float> {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(euler: raw.value))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        return [datum.time.metaWearCSVDate] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "X", "Y", "Z"] }
}

public extension MWDataConvertible where
RawDataType == UInt8,
DataType == Int {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(raw.value))
    }
}

public extension MWDataConvertible where
RawDataType == Int32,
DataType == Int {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(raw.value))
    }
}

public extension MWDataConvertible where
RawDataType == UInt32,
DataType == Int {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(raw.value))
    }
}

// MARK: - Internal (Color)

public extension MWDataConvertible where
RawDataType == MblMwTcs34725ColorAdc,
DataType == MWColorDetector.ColorValue {
    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(r: raw.value.red, g: raw.value.green, b: raw.value.blue, unfilteredClear: raw.value.clear))
    }

    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate] + datum.value.stringify()
    }

    var columnHeadings: [String] { ["Epoch", "Red", "Green", "Blue", "Unfiltered Clear"] }
}

// MARK: - Data Type Conversions

public extension MWDataConvertible where DataType == Int {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Int32 {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Int8 {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Double {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == Float {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, String(datum.value)]
    }
}

public extension MWDataConvertible where DataType == String {
    func asColumns(_ datum: Timestamped<DataType>) -> [String] {
        [datum.time.metaWearCSVDate, datum.value]
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

public extension MWColorDetector.ColorValue {
    func stringify() -> [String] {
        [.init(r), .init(g), .init(b), .init(unfilteredClear)]
    }
}

public extension String {
    static var metaWearStringDecimalDigits = 4
    init(mwDecimals: CVarArg) {
        self.init(format: "%1.\(String.metaWearStringDecimalDigits)", mwDecimals)
    }

    init(mwPercent: Double) {
        self = "\(Int(mwPercent * 100))%"
    }
}

public extension Date {
    /// Time interval since 1970
    var metaWearCSVDate: String { String(mwDecimals: timeIntervalSince1970) }
}
