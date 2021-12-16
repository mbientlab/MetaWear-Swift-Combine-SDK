// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp


/// The haptic module controls a high current driver to power a motor or buzzer (or similar devices).
///
public struct MWBuzzer: MWCommand {

    /// Milliseconds. Specifying .max will run indefinitely. There is no direct stop command (i.e., restart).
    var duration: UInt16

    /// The haptic module controls a high current driver to power a motor or buzzer (or similar devices).
    ///
    /// - Parameters:
    ///   - milliseconds: Duration of the pulse (min ~35 ms depending on strength). UInt16.max is infinite, stopped only by device restart.
    ///
    public init(milliseconds: UInt16) {
        self.duration = milliseconds
    }

    public func command(board: MWBoard) {
        mbl_mw_haptic_start_buzzer(board, duration)
    }
}

/// In the MMR+ model, the coin vibration motor provides haptic feedback by vibrating using the haptic module.
/// The haptic module does not provide PWM (pulse-width modulation) capability.
///
public struct MWHapticMotor: MWCommand {

    /// Milliseconds
    var duration: UInt16
    /// 0 to 1 (max)
    var percentStrength: Float

    /// In the MMR+ model, drives a buzzer for the duration and the strength specified
    ///
    /// - Parameters:
    ///   - milliseconds: Duration of the pulse (min ~35 ms depending on strength). UInt16.max is infinite, stopped only by device restart.
    ///   - percentStrength: Decimal percentage. Low values may not drive the motor for very short pulse durations
    ///
    public init(milliseconds: UInt16, percentStrength: Float) {
        self.percentStrength = max(0.3, min(percentStrength, 1))
        self.duration = max(35, milliseconds)
    }

    public func command(board: MWBoard) {
        mbl_mw_haptic_start_motor(board, percentStrength * 100, duration)
    }
}


// MARK: - Public Presets

public extension MWCommand where Self == MWBuzzer {
    /// Drives a buzzer for the duration specified
    static func buzz(milliseconds: UInt16) -> Self {
        Self.init(milliseconds: milliseconds)
    }
}

public extension MWCommand where Self == MWHapticMotor {
    /// In the MMR+ model, drives a buzzer for the duration and the strength specified
    ///
    /// - Parameters:
    ///   - milliseconds: Duration of the pulse (min ~35 ms depending on strength). UInt16.max is infinite, stopped only by device restart.
    ///   - percentStrength: Decimal percentage. Low values may not drive the motor for very short pulse durations
    ///
    static func buzzMMR(milliseconds: UInt16, percentStrength: Float) -> Self {
        Self.init(milliseconds: milliseconds, percentStrength: percentStrength)
    }
}
