// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp


/// Wipes all data and settings from the MetaWear.
///
public struct MWFactoryReset: MWCommand {
    /// Wipes any data and settings from the MetaWear.
    public init() {}
    public func command(board: MWBoard) {
        mbl_mw_logging_stop(board)
        mbl_mw_metawearboard_tear_down(board)

        mbl_mw_logging_clear_entries(board)
        mbl_mw_event_remove_all(board)
        mbl_mw_macro_erase_all(board)
        
        mbl_mw_debug_reset_after_gc(board)
        mbl_mw_debug_disconnect(board)
    }
}


/// Removes all data processors, loggers, timers, and recorded events from
/// both the board and the struct's internal state. The board itself is not reset,
/// so any configuration changes will be preserved.
///
public struct MWActivitiesReset: MWCommand {
    /// Removes all data processors, loggers, timers, and recorded events from
    /// both the board and the struct's internal state. The board itself is not reset,
    /// so any configuration changes will be preserved.
    public init() {}
    public func command(board: MWBoard) {
        mbl_mw_event_remove_all(board)
        mbl_mw_metawearboard_tear_down(board)
    }
}


/// Restarts, preserving macros, loggers, and settings,
/// but any in-memory activities are lost.
///
public struct MWRestart: MWCommand {
    /// Restarts, preserving macros, loggers, and settings,
    /// but any in-memory activities are lost.
    public init() {}
    public func command(board: MWBoard) {
        mbl_mw_debug_reset(board)
        mbl_mw_debug_disconnect(board)
    }
}


/// Wipes logged data from onboard flash storage.
///
public struct MWDeleteLoggedData: MWCommand {
    /// Wipes logged data from onboard flash storage.
    public init() {}
    public func command(board: MWBoard) {
        mbl_mw_logging_flush_page(board)
        mbl_mw_logging_clear_entries(board)
    }
}


// MARK: - Public Presets

public extension MWCommand where Self == MWFactoryReset {
    /// Wipes any data and settings from the MetaWear.
    static var resetFactoryDefaults: Self { Self() }
}

public extension MWCommand where Self == MWActivitiesReset {
    /// Removes all data processors, loggers, timers, and recorded events from
    /// both the board and the struct's internal state. The board itself is not reset,
    /// so any configuration changes will be preserved.
    static var resetActivities: Self { Self() }
}

public extension MWCommand where Self == MWRestart {
    /// Restarts, preserving macros, loggers, and settings,
    /// but any in-memory activities are lost.
    static var restart: Self { Self() }
}

public extension MWCommand where Self == MWDeleteLoggedData {
    /// Wipes logged data from onboard flash storage.
    static var deleteLoggedData: Self { Self() }
}
