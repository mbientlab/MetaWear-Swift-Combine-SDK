// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

/// Commands for recording, stopping, and removing sequences of commands.
///
public struct MWMacro {
    private init() { }
}

/// The most convenient way to record a macro is using the Combine operators `.macro(executeOnBoot:actions:)` and, if needed, later running manually via `macroExecute()`.
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

    /// Stops recording macro commands and generates an identifier to later execute the macro.
    struct StopRecording: MWCommandWithResponse {
        public init() { }
        public typealias DataType = MWMacroIdentifier

        public func command(device: MetaWear) -> MWPublisher<(result: MWMacroIdentifier, metawear: MetaWear)> {
            let subject = PassthroughSubject<UInt8,MWError>()
            mbl_mw_macro_end_record(device.board, bridge(obj: subject)) { context, _, value in
                let _subject: PassthroughSubject<UInt8,MWError> = bridge(ptr: context!)
                _subject.send(.init(value))
                _subject.send(completion: .finished)
            }
            return Publishers.Zip(_JustMW(device), subject)
                .map { ($1, $0) }
                .erase(subscribeOn: device.bleQueue)
        }
    }

    /// Run the desired macro.
    struct Execute: MWCommand {
        var id: MWMacroIdentifier

        /// Run the desired macro, selected by the id you cached when ending macro recording.
        public init(id: MWMacroIdentifier) {
            self.id = id
        }

        public func command(board: MWBoard) {
            mbl_mw_macro_execute(board, id)
        }
    }

    struct EraseAll: MWCommand {
        public init() {}
        public func command(board: MWBoard) {
            mbl_mw_macro_erase_all(board)
            mbl_mw_debug_reset_after_gc(board)
        }
    }
}



// MARK: - Public Presets
public extension MWCommand where Self == MWMacro.Record {
    static func macroStartRecording(runOnStartup: Bool) -> Self {
        Self.init(runOnStartup: runOnStartup)
    }
}

public extension MWCommandWithResponse where Self == MWMacro.StopRecording {
    /// Returns the identifier for the recorded macro.
    static var macroStopRecordingAndGenerateIdentifier: Self { Self() }
}

public extension MWCommand where Self == MWMacro.EraseAll {
    static var macroEraseAll: Self { Self() }
}

public extension MWCommand where Self == MWMacro.Execute {
    static func macroExecute(id: MWMacroIdentifier) -> Self {
        Self.init(id: id)
    }
}
