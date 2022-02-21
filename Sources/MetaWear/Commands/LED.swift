// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Control the onboard LED by specifying a color to emulate and an activation pattern to repeat
///
public struct MWLED {
    private init() { }
#if os(macOS)
    public typealias MBLColor = NSColor
#else
    public typealias MBLColor = UIColor
#endif
}

public extension MWLED {

    struct Off: MWCommand {
        public func command(board: MWBoard) {
            guard MWModules.lookup(in: board, .led) != nil else { return }
            mbl_mw_led_stop_and_clear(board)
        }
    }

    /// Program the LEDs to display a color in a pattern (e.g., pulsing, flashing, solid).
    ///
    /// The MetaWear LEDs have 31 intensity levels for each RGB channel,
    /// so screen colors may not replicate exactly.
    ///
    struct Flash: MWCommand {

        /// RGB color to mimic in the onboard LED color space
        let color: (red: Float, green: Float, blue: Float)
        let pattern: Pattern

        /// Program and play an LED flash pattern.
        ///
        public init(color: MBLColor, pattern: MWLED.Flash.Pattern) {
            self.pattern = pattern
            self.color = MWLED.getRGBChannels(color: color)
        }

        public func command(board: MWBoard) {
            guard MWModules.lookup(in: board, .led) != nil else { return }

            mbl_mw_led_stop_and_clear(board)

            let scale = MWLED.Flash.Pattern.scaleChannel
            var cppPattern = self.pattern._convertedToCPP()

            let maxRed = scale(color.red, pattern.intensityCeiling)
            if maxRed > 0 {
                cppPattern.low_intensity  = scale(color.red, pattern.intensityFloor)
                cppPattern.high_intensity = maxRed
                mbl_mw_led_write_pattern(board, &cppPattern, MBL_MW_LED_COLOR_RED)
            }

            let maxGreen = scale(color.green, pattern.intensityCeiling)
            if maxGreen > 0 {
                cppPattern.low_intensity  = scale(color.green, pattern.intensityFloor)
                cppPattern.high_intensity = maxGreen
                mbl_mw_led_write_pattern(board, &cppPattern, MBL_MW_LED_COLOR_GREEN)
            }

            let maxBlue = scale(color.blue, pattern.intensityCeiling)
            if maxBlue > 0 {
                cppPattern.low_intensity  = scale(color.blue, pattern.intensityFloor)
                cppPattern.high_intensity = maxBlue
                mbl_mw_led_write_pattern(board, &cppPattern, MBL_MW_LED_COLOR_BLUE)
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

    /// Start an LED flash pattern.
    /// - Parameters:
    ///   - color: RGB color to mimic
    ///   - pattern: Dynamics for how the LED turns on and off
    ///
    static func led(_ color: MWLED.MBLColor, _ pattern: MWLED.Flash.Pattern) -> Self {
        Self.init(color: color, pattern: pattern)
    }

    /// Start a preset LED flash pattern. You can iterate over ``MWLED.Preset``
    /// for easy identification of a MetaWear in a list.
    ///
    /// - Parameters:
    ///   - color: RGB color to mimic
    ///   - pattern: Dynamics for how the LED turns on and off
    ///
    static func led(groupPreset preset: MWLED.Preset) -> Self {
        preset.command
    }

    /// Start a preset LED flash pattern. You can iterate over ``MWLED.Preset``
    /// for easy identification of a MetaWear in a list.
    ///
    /// - Parameters:
    ///   - color: RGB color to mimic
    ///   - pattern: Dynamics for how the LED turns on and off
    ///
    static func led(groupIndex: Int) -> Self {
        let index = max(0, min(groupIndex % 10, MWLED.Preset.allCases.endIndex - 1))
        return MWLED.Preset.allCases[index].command
    }
}

public extension MWLED {

    /// Colors and patterns convenient for identifying devices in groups.
    ///
    enum Preset: Int, IdentifiableByRawValue, CaseIterable {
        case zero, one, two, three, four, five, six, seven, eight, nine

        public var color: MBLColor {
            switch self {
                case .zero, .three, .six:  return .cyan
                case .one, .four, .seven:  return .orange
                case .two, .five, .eight:  return .white
                case .nine:                return .purple
            }
        }

        public var pattern: MWLED.Flash.Pattern {
            switch self {
                case .zero, .one, .two:    return .easeInOut(repetitions: 2)
                case .three, .four, .five: return .blink(repetitions: 4, lowIntensity: 0.25)
                case .six, .seven, .eight: return .blinkQuickly(repetitions: 6)
                case .nine:                return .easeInOut(repetitions: 3)
            }
        }

        var command: MWLED.Flash { .init(color: color, pattern: pattern) }
    }
}

// MARK: - Flash Patterns

public extension MWLED.Flash {

    /// Dynamics of the LED strobe pattern and its repetition.
    ///
    struct Pattern: Equatable, Hashable {

        /// Highest intensity. Percentage in 0 to 1 format. (MetaWears only support 31 steps of intensity.)
        public var intensityCeiling: Float

        /// Lowest intensity. Percentage in 0 to 1 format. (MetaWears only support 31 steps of intensity.)
        public var intensityFloor: Float

        /// Pattern repeat count or UInt8.max for infinite
        public var repetitions: UInt8

        /// Time for one cycle (off, rise, high, fall) in milliseconds
        public var period: UInt16

        /// Ramp time from off to on, in milliseconds
        public var riseTime: UInt16

        /// Time at max intensity in milliseconds
        public var highTime: UInt16

        /// Ramp time from on to off, in milliseconds
        public var fallTime: UInt16

        /// Offset the pattern repetition
        public var offset: UInt16

        /// For UI that reflects the end of a flashing pattern
        public var totalDuration: Double {
            Double(repetitions) * Double(period / 1000)
        }

        /// For UI that reflects the led's activation
        public var ledActiveTime: Double {
            Double(riseTime + highTime + fallTime)
        }
    }
}

public extension MWLED.Flash.Pattern {

    /// Solid, forever-activated LED
    /// - Parameters:
    ///   - intensity: Maximum brightness (1)
    /// - Returns: Pattern ready for programming
    ///
    static func solid(intensity: Float = 1) -> MWLED.Flash.Pattern {
        .init(intensityCeiling: intensity,
              intensityFloor: intensity,
              repetitions: 0xff,
              period: 1000, riseTime: 0, highTime: 500, fallTime: 0, offset: 0)
    }

    /// Equal rise-fall-on pulse of the LED
    ///
    /// - Parameters:
    ///   - repetitions: Times LED will be activated (.max for forever)
    ///   - onDuration: Time LED is active (ms)
    ///   - offDuration: Time between repetitions (ms)
    ///   - highIntensity: Maximum brightness (1)
    /// - Returns: Pattern ready for programming
    ///
    static func easeInOut(repetitions:   UInt8,
                          onDuration:    UInt16 = 1700,
                          offDuration:   UInt16 = 300,
                          highIntensity: Float = 1) -> MWLED.Flash.Pattern {
        let ramp = UInt16(Float(onDuration) * 0.33)
        let high = onDuration - (ramp * 2)
        return .init(intensityCeiling: highIntensity,
                     intensityFloor: 0,
                     repetitions: repetitions,
                     period: offDuration + onDuration,
                     riseTime: ramp,
                     highTime: high,
                     fallTime: ramp,
                     offset: 0)
    }

    /// 1.2 second long pulse that rises more quickly than it falls.
    /// - Parameters:
    ///   - repetitions: Times LED will be activated (.max for forever)
    ///   - lowIntensity: Minimum brightness (0)
    ///
    static func pulse(repetitions: UInt8) -> MWLED.Flash.Pattern {
        .init(intensityCeiling: 1,
              intensityFloor: 0,
              repetitions: repetitions,
              period: 1200,
              riseTime: 150,
              highTime: 380,
              fallTime: 400,
              offset: 0)
    }

    /// One 70 ms sharp blink every 0.4 seconds
    /// - Parameters:
    ///   - repetitions: Times LED will be activated (.max for forever)
    ///   - lowIntensity: Minimum brightness (0)
    ///
    static func blinkQuickly(repetitions: UInt8, lowIntensity: Float = 0) -> MWLED.Flash.Pattern {
        .init(intensityCeiling: 1,
              intensityFloor: lowIntensity,
              repetitions: repetitions,
              period: 400,
              riseTime: 0,
              highTime: 70,
              fallTime: 0,
              offset: 0)
    }

    /// One 100 ms sharp blink every second
    /// - Parameters:
    ///   - repetitions: Times LED will be activated (.max for forever)
    ///   - lowIntensity: Minimum brightness (0)
    ///
    static func blink(repetitions: UInt8, lowIntensity: Float = 0) -> MWLED.Flash.Pattern {
        .init(intensityCeiling: 1,
              intensityFloor: lowIntensity,
              repetitions: repetitions,
              period: 1000,
              riseTime: 0,
              highTime: 100,
              fallTime: 0,
              offset: 0)
    }

    /// One 100 ms sharp blink every 5 seconds (or as specified, down to 1500 ms)
    /// - Parameters:
    ///   - repetitions: Times LED will be activated (.max for forever)
    ///   - lowIntensity: Minimum brightness (0)
    ///   - period: Time for one cycle (off, rise, high, fall) in milliseconds (min 1500 ms)
    ///
    static func blinkInfrequently(repetitions: UInt8, period: UInt16 = 5000, lowIntensity: Float = 0) -> MWLED.Flash.Pattern {
        .init(intensityCeiling: 1,
              intensityFloor: lowIntensity,
              repetitions: repetitions,
              period: max(1500, period),
              riseTime: 0,
              highTime: 100,
              fallTime: 0,
              offset: 0)
    }

    /// Custom LED activation dynamics
    ///
    /// - Parameters:
    ///   - repetitions: Pattern repeat count or UInt8.max for infinite
    ///   - period: Time for one cycle (off, rise, high, fall) in milliseconds
    ///   - riseTime: Ramp time from off to on, in milliseconds
    ///   - highTime: Time at max intensity in milliseconds
    ///   - fallTime: Ramp time from on to off, in milliseconds
    ///   - offset: Time offset for a cycle
    ///   - intensityCeiling: Highest intensity. Percentage in 0 to 1 format. (MetaWears only support 31 steps of intensity.)
    ///   - intensityFloor: Lowest intensity. Percentage in 0 to 1 format. (MetaWears only support 31 steps of intensity.)
    ///
    /// - Returns: Flash pattern
    ///
    static func custom(repetitions: UInt8, period: UInt16, riseTime: UInt16, highTime: UInt16, fallTime: UInt16, offset: UInt16, intensityCeiling: Float, intensityFloor: Float) -> MWLED.Flash.Pattern {
        .init(intensityCeiling: intensityCeiling, intensityFloor: intensityFloor, repetitions: repetitions, period: period, riseTime: riseTime, highTime: highTime, fallTime: fallTime, offset: offset)
    }
}

// MARK: - Flash Emulator

public extension MWLED.Flash {

    /// Load your own pattern and call `emulate` to recreate the MetaWear's LED behavior
    /// in a SwiftUI view or by subscribing to the `ledIsOnPublisher`.
    class Emulator: ObservableObject {

        @Published public var color: MWLED.MBLColor
        @Published public var pattern: MWLED.Flash.Pattern
        public var ledIsOn: Bool { _ledSubject.value }
        public private(set) lazy var ledIsOnPublisher = _ledSubject.share().eraseToAnyPublisher()

        public func emulate() {
            let cycleDuration = Double(pattern.period) / 1000
            let flashDuration = Double(pattern.ledActiveTime) / 1000
            let start = DispatchTime.now()

            Array(1...pattern.repetitions).forEach { rep in
                let cycleStart = cycleDuration * Double(rep - 1)

                DispatchQueue.main.asyncAfter(deadline: start + cycleStart) { [weak self] in
                    self?._ledSubject.send(true)

                    DispatchQueue.main.asyncAfter(deadline: start + cycleStart + flashDuration) { [weak self] in
                        self?._ledSubject.send(false)
                    }
                }
            }
        }

        public init(_ pattern: MWLED.Flash.Pattern, _ color: MWLED.MBLColor) {
            self.pattern = pattern
            self.color = color
            _objectWillChange = self._ledSubject.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }

        public convenience init(preset: MWLED.Preset) {
            self.init(preset.pattern, preset.color)
        }

        private let _ledSubject = CurrentValueSubject<Bool,Never>(false)
        private var _objectWillChange: AnyCancellable? = nil
    }
}


// MARK: - Internal conversion methods

extension MWLED {

    private static func getRGBChannels(color: MBLColor) -> (red: Float, green: Float, blue: Float) {
        var red:   CGFloat = 0
        var green: CGFloat = 0
        var blue:  CGFloat = 0
        var _color = color
#if os(macOS)
        if [NSColorSpace.sRGB, NSColorSpace.extendedSRGB].contains(color) == false {
            _color = color.usingColorSpace(.sRGB) ?? .white
        }
        if _color.numberOfComponents == 2 {
            _color.getWhite(&red, alpha: nil)
            (blue, green) = (red, red)
        } else {
            _color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        }
#else
        _color.getRed(&red, green: &green, blue: &blue, alpha: nil)
#endif
        return (Float(red), Float(green), Float(blue))
    }

#if canImport(SwiftUI)
    @available(iOS 14.0, macOS 11.0, *)
    private static func getRGBChannels(swiftUI color: Color) -> (red: Float, green: Float, blue: Float) {
        let converted = color.cgColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) ?? .init(srgbRed: 1, green: 1, blue: 1, alpha: 1)
#if os(macOS)
        let _color = NSColor(cgColor: converted) ?? .white
#else
        let _color = UIColor(cgColor: converted)
#endif
        return getRGBChannels(color: _color)
    }
#endif
}

extension MWLED.Flash.Pattern {

    fileprivate static let maxIntensityScale = UInt8(31)

    /// Scales a 0 to 1 value to 0 31 MetaWear
    fileprivate static func scaleChannel(_ value: Float, intensity: Float) -> UInt8 {
        let scaledChannel = value * intensity
        let scaledToMetaWear = scaledChannel * Float(Self.maxIntensityScale)
        let metawearColorSpace = UInt8(round(scaledToMetaWear))
        return max(0, min(Self.maxIntensityScale, metawearColorSpace))
    }

    public func _convertedToCPP() -> MblMwLedPattern {
        return .init(
            high_intensity: UInt8(self.intensityCeiling * Float(Self.maxIntensityScale)),
            low_intensity: UInt8(self.intensityFloor * Float(Self.maxIntensityScale)),
            rise_time_ms: self.riseTime,
            high_time_ms: self.highTime,
            fall_time_ms: self.fallTime,
            pulse_duration_ms: self.period,
            delay_time_ms: self.offset,
            repeat_count: self.repetitions
        )
    }
}
