// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

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

    /// Call via .command or via .macro Combine operators.
    struct StopRecording: MWCommandOutcome {
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
}



// MARK: - Public Presets
public extension MWCommandOutcome where Self == MWMacro.StopRecording {
    static func macroEndRecording() -> Self {
        Self.init()
    }
}

public extension MWCommand where Self == MWMacro.Record {
    static func macroStartRecording(runOnStartup: Bool) -> Self {
        Self.init(runOnStartup: runOnStartup)
    }
}
