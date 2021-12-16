// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

public extension MWStreamable where Self == MWMechanicalButton {
    static func mechanicalButton() -> Self { Self() }
}
public extension MWLoggable where Self == MWMechanicalButton {
    static func mechanicalButton() -> Self { Self() }
}

// MARK: - Signals

public struct MWMechanicalButton: MWStreamable, MWLoggable {

    public typealias DataType = MWMechanicalButton.State
    public typealias RawDataType = UInt32
    public let signalName: MWNamedSignal = .mechanicalButton
    public var columnHeadings = ["Epoch", "Switch State"]
}

public extension MWMechanicalButton {

    func streamSignal(board: MWBoard) throws -> MWDataSignal? {
        mbl_mw_switch_get_state_data_signal(board)
    }

    func streamConfigure(board: MWBoard) {}
    func streamStart(board: MWBoard) {}
    func streamCleanup(board: MWBoard) {}

    func convert(from raw: Timestamped<RawDataType>) -> Timestamped<DataType> {
        (raw.time, .init(value: raw.value))
    }

    func asColumns(_ datum: Timestamped<State>) -> [String] {
        [datum.time.metaWearCSVDate, datum.value.label]
    }
}


// MARK: - Signal Implementations

public extension MWMechanicalButton {

    enum State: String, CaseIterable, IdentifiableByRawValue {
        case up
        case down

        public init(value: UInt32) {
            if value == 0 { self = .up }
            else { self = .down }
        }

        public var label: String { self.rawValue.localizedCapitalized }
    }
}
