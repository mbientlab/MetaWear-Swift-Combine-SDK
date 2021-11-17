////Copyright

import Foundation

public enum MetaWearError: Error {

    /// Operation failed. Generic failure, see message for details
    case operationFailed(_ message: String)

    /// Bluetooth unsupported on this platform
    case bluetoothUnsupported

    /// Bluetooth unauthorized in this App
    case bluetoothUnauthorized

    /// Bluetooth powered off
    case bluetoothPoweredOff
}

extension MetaWearError: LocalizedError {

    public var errorDescription: String? {
        switch self {
            case .operationFailed(let msg): return "Operation failed: \(msg)"
            case .bluetoothUnsupported:     return "Bluetooth unsupported on this platform"
            case .bluetoothUnauthorized:    return "Bluetooth unauthorized in this App"
            case .bluetoothPoweredOff:      return "Bluetooth powered off"
        }
    }

    /// Useful for mutating or chaining multiple operation failed messages.
    ///
    internal var chainableDescription: String {
        switch self {
            case .operationFailed(let msg): return msg
            default: return self.errorDescription ?? ""
        }
    }
}
