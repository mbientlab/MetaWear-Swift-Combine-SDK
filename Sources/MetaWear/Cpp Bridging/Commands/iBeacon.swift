// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine
import MetaWearCpp

public struct MWiBeacon {
    private init() { }
}

public extension MWiBeacon {

    /// Begin iBeacon mode
    struct Start: MWCommand {
        public init() {}
        public func command(board: MWBoard) {
            mbl_mw_ibeacon_set_major(board, 78)
            mbl_mw_ibeacon_set_minor(board, 7453)
            mbl_mw_ibeacon_set_period(board, 15027)
            mbl_mw_ibeacon_set_rx_power(board, -55)
            mbl_mw_ibeacon_set_tx_power(board, -12)
            loadUUID(board: board)
            mbl_mw_ibeacon_enable(board)
        }

        private func loadUUID(board: MWBoard) {
            let uuid = UUID().uuidString
            let array: [UInt8] = Array(uuid.utf8)

            let count = array.count
            let uploadPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            uploadPointer.initialize(repeating: 0, count: count)

            defer {
                uploadPointer.deinitialize(count: count)
                uploadPointer.deallocate()
            }

            uploadPointer.pointee = array[0]
            for index in 1..<array.endIndex {
                uploadPointer.advanced(by: 1).pointee = array[index]
            }

            mbl_mw_ibeacon_set_uuid(board, uploadPointer)
        }
    }

    /// Exit iBeacon mode
    struct Stop: MWCommand {
        public init() {}
        public func command(board: MWBoard) {
            mbl_mw_ibeacon_disable(board)
        }
    }
}



// MARK: - Public Presets

public extension MWCommand where Self == MWiBeacon.Start {
    static func iBeaconStart() -> Self {
        Self.init()
    }
}

public extension MWCommand where Self == MWiBeacon.Stop {
    static func iBeaconStop() -> Self {
        Self.init()
    }
}
