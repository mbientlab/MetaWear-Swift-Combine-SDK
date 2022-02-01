// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp
import Combine


// MARK: - Discoverable Presets

public extension MWStreamable where Self == MWMechanicalButton {
    static var mechanicalButton: Self { Self() }
}
public extension MWLoggable where Self == MWMechanicalButton {
    static var mechanicalButton: Self { Self() }
}

// MARK: - Signals

public struct MWMechanicalButton: MWStreamable, MWLoggable {
    public init() { }
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

    /// When the button is pressed
    ///
    func getDownEventSignal(board: MWBoard) -> MWPublisher<MWDataProcessorSignal> {
        guard let stream = mbl_mw_switch_get_state_data_signal(board) else {
            return _Fail(mw: .operationFailed("Could not create button signal"))
        }
        return stream.filter(.equals, reference: 1)
    }

    /// When the button is released
    ///
    func getUpEventSignal(board: MWBoard) -> MWPublisher<MWDataProcessorSignal> {
        guard let stream = mbl_mw_switch_get_state_data_signal(board) else {
            return _Fail(mw: .operationFailed("Could not create button signal"))
        }
        return stream.filter(.equals, reference: 0)
    }

}


// MARK: - Signal Implementations

public extension MWMechanicalButton {

    enum State: CaseIterable, IdentifiableByRawValue {


        case up
        case down
        case custom(UInt8)

        public init(value: UInt32) {
            switch value {
                case 0: self = .up
                case 1: self = .down
                default: self = .custom(UInt8(value))
            }
        }

        public var label: String { self.rawValue }

        public var rawValue: String {
            switch self {
                case .up: return "Up"
                case .down: return "Down"
                case .custom(let flag): return "\(flag)"
            }
        }

        public init?(rawValue: String) {
            switch rawValue {
                case "Up": self = .up
                case "Down": self = .down
                default:
                    if let int = UInt8(rawValue) { self = .custom(int) }
                    else { return nil }
            }
        }

        public static var allCases: [MWMechanicalButton.State] = [.up, .down]

    }
}
