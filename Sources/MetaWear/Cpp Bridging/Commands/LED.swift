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

    /// Simplify common LED operations with a straightforward interface
    /// Use mbl_mw_led_write_pattern for precise control
    ///
    struct Flash: MWCommand {

        var color: MWLED.MBLColor
        var intensity: Float
        var repetitions: UInt8
        var duration: UInt16
        var period: UInt16

        /// Program a one-time LED flash pattern.
        /// - Parameters:
        ///   - color: RGB color to mimic
        ///   - intensity: 0 to 1 brightness value
        ///   - repetitions: Flash count (UInt8.max for infinite)
        ///   - duration: A flash's duration in milliseconds
        ///   - period: Spacing between flashes in milliseconds
        ///
        public init(color: MWLED.MBLColor,
                    intensity: Float,
                    repetitions: UInt8 = 0xFF,
                    duration: UInt16 = 200,
                    period: UInt16 = 800) {
            self.color = color
            self.intensity = max(0, min(1, intensity))
            self.repetitions = repetitions
            self.duration = duration
            self.period = period
        }

        public init(pattern: MWLED.Flash.Pattern) {
            self.color = pattern.color
            self.intensity = pattern.intensity
            self.repetitions = pattern.repetitions
            self.duration = pattern.duration
            self.period = pattern.period
        }

        public func command(board: MWBoard) {
            guard MWModules.lookup(in: board, .led) != nil else { return }
            let scaledIntensity = CGFloat(intensity) * 31.0
            let rtime = duration / 2
            let ftime = duration / 2
            let offset: UInt16 = 0

            var red: CGFloat = 0
            var blue: CGFloat = 0
            var green: CGFloat = 0

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
    /// Start a one-time LED flash pattern.
    /// - Parameters:
    ///   - color: RGB color to mimic
    ///   - intensity: 0 to 1 brightness value
    ///   - repetitions: Flash count (UInt8.max for infinite)
    ///   - duration: A flash's duration in milliseconds (e.g., 200)
    ///   - period: Spacing between flashes in milliseconds (e.g., 800)
    ///
    static func ledFlash(color: MWLED.MBLColor,
                         intensity: Float,
                         repetitions: UInt8 = 0xFF,
                         duration: UInt16 = 200,
                         period: UInt16 = 800) -> Self {
        Self.init(color: color, intensity: intensity, repetitions: repetitions, duration: duration, period: period)
    }

    static func ledFlash(_ pattern: MWLED.Flash.Pattern) -> Self {
        Self.init(pattern: pattern)
    }
}

public extension MWLED.Flash {

    /// A one-time LED flash pattern.
    ///
    /// Duration specifies the length of a flash in milliseconds (e.g., 400).
    /// Period specifies the spacing between the start of flashes (e.g., 800).
    ///
    struct Pattern: Equatable, Hashable {

        /// RGB color to mimic
        public var color: MWLED.MBLColor

        /// 0 to 1 brightness value (MetaWears support 31 intermediate steps)
        public var intensity: Float

        /// Flash count (UInt8.max for infinite)
        public var repetitions: UInt8

        /// A flash's duration in milliseconds
        public var duration: UInt16

        /// Spacing between flashes in milliseconds
        public var period: UInt16

        /// For UI state that reflects the end of a flashing pattern
        public var totalDuration: Double {
            Double(repetitions) * Double(duration / 1000)
        }

        /// A one-time LED flash pattern.
        ///
        /// - Parameters:
        ///   - color: RGB color to mimic
        ///   - intensity: 0 to 1 brightness value
        ///   - repetitions: Flash count (UInt8.max for infinite)
        ///   - duration: A flash's duration in milliseconds (e.g., 200)
        ///   - period: Spacing between flashes in milliseconds (e.g., 800)
        ///
        public init(color: MWLED.MBLColor, intensity: Float, repetitions: UInt8, duration: UInt16, period: UInt16) {
            self.color = color
            self.intensity = max(0, min(1, intensity))
            self.repetitions = repetitions
            self.duration = duration
            self.period = period
        }

        #if canImport(SwiftUI)
        /// A one-time LED flash pattern.
        ///
        /// - Parameters:
        ///   - color: RGB color to mimic
        ///   - intensity: 0 to 1 brightness value
        ///   - repetitions: Flash count (UInt8.max for infinite)
        ///   - duration: A flash's duration in milliseconds (e.g., 200)
        ///   - period: Spacing between flashes in milliseconds (e.g., 800)
        ///
        @available(iOS 14.0, macOS 12.0, *)
        public init(_ color: Color, intensity: Float, repetitions: UInt8, duration: UInt16, period: UInt16) {
            let converted = color.cgColor?.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) ?? .init(srgbRed: 1, green: 1, blue: 1, alpha: 1)
            #if os(macOS)
            self.color = .init(cgColor: converted) ?? .white
            #else
            self.color = .init(cgColor: converted)
            #endif
            self.intensity = intensity
            self.repetitions = repetitions
            self.duration = duration
            self.period = period
        }
        #endif
    }
}

// MARK: - Flash Pattern Presets

public extension MWLED.Flash.Pattern {

    /// Color blindness accommodating unique flash patterns for identifying devices in groups.
    enum Presets: Int, IdentifiableByRawValue, CaseIterable {
        case zero
        case one
        case two
        case three
        case four
        case five
        case six
        case seven
        case eight
        case nine

        public var pattern: MWLED.Flash.Pattern {
            switch self {
                case .zero: return .init(color: .cyan, intensity: 1, repetitions: 2, duration: 300, period: 800)
                case .one: return .init(color: .orange, intensity: 1, repetitions: 2, duration: 300, period: 800)
                case .two: return .init(color: .white, intensity: 1, repetitions: 2, duration: 300, period: 800)
                case .three: return .init(color: .cyan, intensity: 1, repetitions: 1, duration: 400, period: 800)
                case .four: return .init(color: .orange, intensity: 1, repetitions: 1, duration: 400, period: 800)
                case .five: return .init(color: .white, intensity: 1, repetitions: 1, duration: 400, period: 800)
                case .six: return .init(color: .cyan, intensity: 1, repetitions: 3, duration: 150, period: 700)
                case .seven: return .init(color: .orange, intensity: 1, repetitions: 3, duration: 150, period: 700)
                case .eight: return .init(color: .white, intensity: 1, repetitions: 3, duration: 150, period: 700)
                case .nine: return .init(color: .purple, intensity: 1, repetitions: 5, duration: 100, period: 500)
            }
        }
    }
}

// MARK: - Flash Emulator

public extension MWLED.Flash.Pattern {

    /// Load your own pattern and call `emulate` to recreate the MetaWear's LED behavior
    /// in a SwiftUI view or by subscribing to the `ledIsOnPublisher`.
    class Emulator: ObservableObject {

        @Published public var pattern: MWLED.Flash.Pattern
        public var ledIsOn: Bool { _ledSubject.value }
        public private(set) lazy var ledIsOnPublisher = _ledSubject.share().eraseToAnyPublisher()

        public func emulate() {
            let cycleDuration = Double(pattern.period) / 1000
            let flashDuration = Double(pattern.duration) / 1000
            let now = DispatchTime.now()

            Array(1...pattern.repetitions).forEach { rep in
                let startDelay = cycleDuration * Double(rep - 1)

                DispatchQueue.main.asyncAfter(deadline: now + startDelay) { [weak self] in
                    self?._ledSubject.send(true)

                    DispatchQueue.main.asyncAfter(deadline: now + startDelay + flashDuration) { [weak self] in
                        self?._ledSubject.send(false)
                    }
                }

            }
        }

        public init(_ pattern: MWLED.Flash.Pattern) {
            self.pattern = pattern
            _objectWillChange = self._ledSubject.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        }

        public convenience init(preset: MWLED.Flash.Pattern.Presets) {
            self.init(preset.pattern)
        }

        private let _ledSubject = CurrentValueSubject<Bool,Never>(false)
        private var _objectWillChange: AnyCancellable? = nil
    }
}
