// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine

// MARK: - Signals

public struct MWHumidity: MWPollable, MWReadable {

    public typealias DataType = Float
    public typealias RawDataType = Float
    public let columnHeadings = ["Epoch", "Humidity"]
    public var loggerName: MWLogger = .humidity

    public var oversampling: Oversampling? = nil
    public var pollingRate: MWFrequency

    public init(oversampling: MWHumidity.Oversampling? = nil, rate: MWFrequency) {
        self.oversampling = oversampling
        self.pollingRate = rate
    }
}

public extension MWHumidity {

    func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_humidity_bme280_get_percentage_data_signal(board)
    }

    func readConfigure(board: MWBoard) {
        guard let oversampling = oversampling else { return }
        mbl_mw_humidity_bme280_set_oversampling(board, oversampling.cppEnumValue)
    }

    func readCleanup(board: MWBoard) { }
}


// MARK: - Discoverable Presets

public extension MWPollable where Self == MWHumidity {
    static func humidity(oversampling: MWHumidity.Oversampling? = nil, rate: MWFrequency) -> Self {
        Self(oversampling: oversampling, rate: rate)
    }
}

public extension MWReadable where Self == MWHumidity {
    static func humidity(oversampling: MWHumidity.Oversampling? = nil) -> Self {
        Self(oversampling: oversampling, rate: .init(eventsPerSecond: 1))
    }
}

// MARK: - C++ Constants
public extension MWHumidity {

    enum Oversampling: Int, CaseIterable, IdentifiableByRawValue {
        case x1 = 1
        case x2 = 2
        case x4 = 4
        case x8 = 8
        case x16 = 16

        public var cppEnumValue: MblMwHumidityBme280Oversampling {
            switch self {
                case .x1:  return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_1X
                case .x2:  return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_2X
                case .x4:  return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_4X
                case .x8:  return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_8X
                case .x16: return MBL_MW_HUMIDITY_BME280_OVERSAMPLING_16X
            }
        }
    }
}
