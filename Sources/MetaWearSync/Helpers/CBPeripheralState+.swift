// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import CoreBluetooth

public extension CBPeripheralState {
    var ranking: Int {
        switch self {
            case .disconnecting: return 0
            case .disconnected: return 1
            case .connecting: return 2
            case .connected: return 3
            default: return 0
        }
    }

    var label: String {
        switch self {
            case .disconnecting: return "Disconnecting"
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting"
            case .connected: return "Connected"
            @unknown default: return "Unknown"
        }
    }
}

extension CBPeripheralState: Comparable {
    public static func < (lhs: CBPeripheralState, rhs: CBPeripheralState) -> Bool {
        lhs.ranking < rhs.ranking
    }
}

public extension CBManagerState {

    var label: String {
        switch self {
            case .resetting: return "Resetting"
            case .unsupported: return "Unsupported"
            case .unauthorized: return "Unauthorized"
            case .poweredOff: return "Off"
            case .poweredOn: return "On"
            default: return "Unknown"
        }
    }

    var isProblematic: Bool {
        self != .poweredOn && self != .resetting
    }
}
