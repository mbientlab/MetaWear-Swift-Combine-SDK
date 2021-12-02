// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

public struct MWMacro {
    private init() { }
}

public extension MWMacro {

    /// Start recording any subsequent commands into a macro.
    struct Record: MWCommand {
        var runOnStartup: Bool

        public init(runOnStartup: Bool) {
            self.runOnStartup = runOnStartup
        }

        public func command(board: MWBoard) {
            mbl_mw_macro_record(board, runOnStartup ? 1 : 0)
        }
    }

    /// Calling the Publisher method on MWBoard provides a callback with the commands recorded.
    struct StopRecording: MWCommand {
        public init() { }

        public func command(board: MWBoard) {
            let subject = _MWStatusSubject()
            mbl_mw_macro_end_record(board, bridge(obj: subject)) { _, _, value in
                print("Recored commands \(value)")
            }
        }
    }
}



// MARK: - Public Presets
public extension MWCommand where Self == MWMacro.StopRecording {
    static func macroEndRecording() -> Self {
        Self.init()
    }
}

public extension MWCommand where Self == MWMacro.Record {
    static func macroStartRecording(runOnStartup: Bool) -> Self {
        Self.init(runOnStartup: runOnStartup)
    }
}
