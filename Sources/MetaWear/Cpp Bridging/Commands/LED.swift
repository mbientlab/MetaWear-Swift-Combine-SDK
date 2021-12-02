// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct MWLED {
    private init() { }

    public struct Intensity {
        let value: CGFloat
        init(_ value: CGFloat) {
            self.value = max(0, min(1, value))
        }
    }

#if os(macOS)
    public typealias MBLColor = NSColor
#else
    public typealias MBLColor = UIColor
#endif
}

public extension MWLED {

    struct Off: MWCommand {
        public func command(board: MWBoard) {
            guard MWModules.lookup(in: board, MBL_MW_MODULE_LED) != nil else { return }
            mbl_mw_led_stop_and_clear(board)
        }
    }

    /// Simplify common LED operations with a straightforward interface
    /// Use mbl_mw_led_write_pattern for precise control
    ///
    struct Flash: MWCommand {

        var color: MWLED.MBLColor
        var intensity: MWLED.Intensity
        var repetitions: UInt8
        var duration: UInt16
        var period: UInt16

        public init(color: MWLED.MBLColor,
                    intensity: MWLED.Intensity,
                    repetitions: UInt8 = 0xFF,
                    duration: UInt16 = 200,
                    period: UInt16 = 800) {
            self.color = color
            self.intensity = intensity
            self.repetitions = repetitions
            self.duration = duration
            self.period = period
        }

        public func command(board: MWBoard) {
            guard MWModules.lookup(in: board, MBL_MW_MODULE_LED) != nil else { return }
            let scaledIntensity = intensity.value * 31.0
            let rtime = duration / 2
            let ftime = duration / 2
            let offset: UInt16 = 0

            var red: CGFloat = 0
            var blue: CGFloat = 0
            var green: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: nil)
            let scaledRed = UInt8(round(red * scaledIntensity))
            let scaledBlue = UInt8(round(blue * scaledIntensity))
            let scaledGreen = UInt8(round(green * scaledIntensity))

            var pattern = MblMwLedPattern(high_intensity: 31,
                                          low_intensity: 0,
                                          rise_time_ms: rtime,
                                          high_time_ms: duration,
                                          fall_time_ms: ftime,
                                          pulse_duration_ms: period,
                                          delay_time_ms: offset,
                                          repeat_count: repetitions)
            mbl_mw_led_stop_and_clear(board)
            if (scaledRed > 0) {
                pattern.high_intensity = scaledRed
                mbl_mw_led_write_pattern(board, &pattern, MBL_MW_LED_COLOR_RED)
            }
            if (scaledGreen > 0) {
                pattern.high_intensity = scaledGreen
                mbl_mw_led_write_pattern(board, &pattern, MBL_MW_LED_COLOR_GREEN)
            }
            if (scaledBlue > 0) {
                pattern.high_intensity = scaledBlue
                mbl_mw_led_write_pattern(board, &pattern, MBL_MW_LED_COLOR_BLUE)
            }
            mbl_mw_led_play(board)
        }
    }
}



// MARK: - Public Presets

public extension MWCommand where Self == MWLED.Off {
    static var ledOff: Self { Self() }
}


public extension MWCommand where Self == MWLED.Flash {
    static func ledFlash(color: MWLED.MBLColor,
                         intensity: MWLED.Intensity,
                         repetitions: UInt8 = 0xFF,
                         duration: UInt16 = 200,
                         period: UInt16 = 800) -> Self {
        Self.init(color: color, intensity: intensity, repetitions: repetitions, duration: duration, period: period)
    }
}
