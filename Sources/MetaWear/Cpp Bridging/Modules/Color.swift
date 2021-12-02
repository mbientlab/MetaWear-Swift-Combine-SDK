// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWColorDetector: MWPollable, MWReadable {

    public typealias DataType = ColorValue
    public typealias RawDataType = MblMwTcs34725ColorAdc
    public var loggerName: MWLogger = .color

    public var gain: Gain? = nil
    public var pollingRate: MWFrequency
    public private(set) var integrationTime: Double

    public init(gain: Gain? = nil, integrationTime: Double, rate: MWFrequency) throws {
        self.gain = gain
        self.pollingRate = rate
        self.integrationTime = 0
        try self.setIntegrationTime(integrationTime)
    }

    /// In milliseconds
    public static let validIntegrationTimesMS = (2.4...614.4)

    public mutating func setIntegrationTime(_ time: Double) throws {
        guard Self.validIntegrationTimesMS.contains(time), time.remainder(dividingBy: 2.4) < 0.001
        else { throw MWError.operationFailed("Invalid timing. Must be increment of 2.4 ms and between 2.4 and 614.4 ms.") }
        let t = time - time.remainder(dividingBy: 2.4)
        self.integrationTime = t
    }
}

public extension MWColorDetector {

    func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_cd_tcs34725_get_adc_data_signal(board)
    }

    func readConfigure(board: MWBoard) {
        mbl_mw_cd_tcs34725_disable_illuminator_led(board)
        guard let gain = gain else { return }
        mbl_mw_cd_tcs34725_set_gain(board, gain.cppEnumValue)
        mbl_mw_cd_tcs34725_set_integration_time(board, Float(integrationTime))
        mbl_mw_cd_tcs34725_write_config(board)
    }

    func readCleanup(board: MWBoard) {
        mbl_mw_cd_tcs34725_enable_illuminator_led(board)
    }

}


// MARK: - Discoverable Presets

public extension MWPollable where Self == MWColorDetector {
    static func colorDetector(gain: MWColorDetector.Gain?, rate: MWFrequency) -> Self {
        try! Self(gain: gain, integrationTime: 36, rate: rate)
    }
}

public extension MWReadable where Self == MWColorDetector {
    static func colorDetector(gain: MWColorDetector.Gain?) -> Self {
        try! Self(gain: gain, integrationTime: 36, rate: .init(eventsPerSecond: 1))
    }
}

// MARK: - C++ Constants

public extension MWColorDetector {

    enum Gain: Int, CaseIterable, IdentifiableByRawValue {
        case x1 = 1
        case x4 = 4
        case x16 = 16
        case x60 = 60

        public var cppEnumValue: MblMwColorDetectorTcs34725Gain {
            switch self {
                case .x1:  return MBL_MW_CD_TCS34725_GAIN_1X
                case .x4:  return MBL_MW_CD_TCS34725_GAIN_4X
                case .x16: return MBL_MW_CD_TCS34725_GAIN_16X
                case .x60: return MBL_MW_CD_TCS34725_GAIN_60X
            }
        }
    }

    enum PresetFrequency: Float, CaseIterable, IdentifiableByRawValue {
        case hz1   = 614.4
        case hz25  = 36
        case hz50  = 16.8
        case hz100 = 7.2
    }

    struct ColorValue {
        var r: UInt16
        var g: UInt16
        var b: UInt16
        var unfilteredClear: UInt16
    }
}
