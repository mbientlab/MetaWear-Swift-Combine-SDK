// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp


/// Inserts a custom value into the Mechanical Button log, if the logger is active.
/// You could use this to mark the start and stop times of a trial run, for example,
/// or to log a qualitative value at a time point.
///
public struct MWLogUserEvent: MWCommand {

    /// Flag to insert in the mechanical button log
    var flag: UInt8

    /// Inserts a custom value into the Mechanical Button log, if the logger is active.
    /// You could use this to mark the start and stop times of a trial run, for example,
    /// or to log a qualitative value at a time point.
    ///
    /// - Parameters:
    ///   - flag: Value to log into the mechanical button log (beware 0 and 1 are used for button press and release)
    ///
    public init(flag: UInt8) {
        self.flag = flag
    }

    public func command(board: MWBoard) {
        mbl_mw_debug_spoof_button_event(board, flag)
    }
}


// MARK: - Public Presets

public extension MWCommand where Self == MWLogUserEvent {
    /// Inserts a custom value into the Mechanical Button log, if the logger is active.
    /// You could use this to mark the start and stop times of a trial run, for example,
    /// or to log a qualitative value at a time point.
    ///
    /// Keep in mind the mechanical button uses 0 and 1 for its own signals.
    ///
    static func logUserEvent(flag: UInt8 = 2) -> Self {
        Self.init(flag: flag)
    }
}
