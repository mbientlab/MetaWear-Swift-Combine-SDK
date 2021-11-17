////Copyright

import Foundation
import CoreBluetooth

internal extension CBPeripheralState {

    var debugDescription: String {
        switch self {
            case .disconnected: return "disconnected"
            case .connecting: return "connecting"
            case .connected: return "connected"
            case .disconnecting: return "disconnecting"
            @unknown default:  fatalError("Update app for new CBPeripheral state.")
        }
    }
}
