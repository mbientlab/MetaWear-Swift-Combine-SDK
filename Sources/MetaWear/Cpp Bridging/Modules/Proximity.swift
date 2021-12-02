// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

/// Returns proximity event counts
public struct MWProximity: MWPollable, MWReadable {

    /// Event count
    public typealias DataType = Int
    public typealias RawDataType = UInt8
    public let columnHeadings = ["Epoch", "Event Count"]
    public var loggerName: MWLogger = .proximity

    public var current: TransmitterCurrent?
    /// milliseconds
    public var integrationTimeMS: Double
    public var pollingRate: MWFrequency
    public var pulses: Pulses

    public init(current: TransmitterCurrent? = nil,
                sensitivity: Pulses = .init(1),
                integrationTimeMS: Double = 2.73,
                rate: MWFrequency
    ) {
        self.current = current
        self.pollingRate = rate
        self.pulses = sensitivity
        self.integrationTimeMS = integrationTimeMS
    }
}

public extension MWProximity {

    func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_proximity_tsl2671_get_adc_data_signal(board)
    }

    func readConfigure(board: MWBoard) {
        mbl_mw_cd_tcs34725_disable_illuminator_led(board)
        mbl_mw_proximity_tsl2671_set_transmitter_current(board, current?.cppEnumValue ?? TransmitterCurrent.mA25.cppEnumValue)
        mbl_mw_proximity_tsl2671_set_integration_time(board, Float(integrationTimeMS))
        mbl_mw_proximity_tsl2671_set_n_pulses(board, UInt8(pulses.value))
        mbl_mw_proximity_tsl2671_write_config(board)
    }

    func readCleanup(board: MWBoard) {
        mbl_mw_cd_tcs34725_enable_illuminator_led(board)
    }

}


// MARK: - Discoverable Presets

public extension MWPollable where Self == MWProximity {
    static func proximity(rate: MWFrequency,
                          sensitivity: MWProximity.Pulses = .init(1),
                          current: MWProximity.TransmitterCurrent? = nil
    ) -> Self {
        Self(current: current, sensitivity: sensitivity, rate: rate)
    }
}

public extension MWReadable where Self == MWProximity {
    static func proximity(sensitivity: MWProximity.Pulses = .init(1),
                          current: MWProximity.TransmitterCurrent? = nil
    ) -> Self {
        Self(current: current, sensitivity: sensitivity, rate: .init(eventsPerSecond: 1))
    }
}

// MARK: - C++ Constants

public extension MWProximity {

    enum DetectionWavelengths: Int, CaseIterable, IdentifiableByRawValue {
        case infraredAndVisible
        case infrared
        case dualChannelInfraredAndVisible

        public var cppEnumValue: MblMwProximityTsl2671Channel {
            switch self {
                case .infraredAndVisible: return MBL_MW_PROXIMITY_TSL2671_CHANNEL_0
                case .infrared: return MBL_MW_PROXIMITY_TSL2671_CHANNEL_1
                case .dualChannelInfraredAndVisible: return  MBL_MW_PROXIMITY_TSL2671_CHANNEL_BOTH
            }
        }
    }

    /// Milliamps
    ///  * For boards powered by the CR2032 battery, it is recommended that the current be 25mA or less.
    enum TransmitterCurrent: Double, CaseIterable, IdentifiableByRawValue {
        case mA100 = 100
        case mA50 = 50
        case mA25 = 25
        case mA12_5 = 12.5

        public var cppEnumValue: MblMwProximityTsl2671Current {
            switch self {
                case .mA100: return MBL_MW_PROXIMITY_TSL2671_CURRENT_100mA
                case .mA50: return MBL_MW_PROXIMITY_TSL2671_CURRENT_50mA
                case .mA25: return MBL_MW_PROXIMITY_TSL2671_CURRENT_25mA
                case .mA12_5: return MBL_MW_PROXIMITY_TSL2671_CURRENT_12_5mA
            }
        }
    }

    /// Number of pulses transmitted at a 62.5 kHz rate, with a limit of 32 pulses. Sensitivity increase by the square root of the pulse count.
    struct Pulses {
        public let value: Int
        public init(_ value: Int) {
            self.value = max(1, min(32, value))
        }
    }
}
