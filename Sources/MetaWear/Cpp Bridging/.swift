// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
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

public extension Date {

    /// Time interval since 1970 (ms)
    ///
    var metaWearEpochMS: String {
        String(format: "%1.3f", timeIntervalSince1970)
    }
}
