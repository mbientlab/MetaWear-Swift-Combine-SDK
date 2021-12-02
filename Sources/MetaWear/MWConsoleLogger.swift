// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth

/// Handle messages from MetaWear devices
public protocol MWConsoleLoggerDelegate {
    func logWith(_ level: MWConsoleLogger.LogLevel, message: String)
}

/// Simple logger implementation that prints messages to the console
public class MWConsoleLogger: MWConsoleLoggerDelegate {
    public static let shared = MWConsoleLogger()

    public var didLog: ((String) -> Void)? = nil
    public var minLevel = LogLevel.info
    public func logWith(_ level: LogLevel, message: String) {
        guard level.rawValue >= minLevel.rawValue else {
            return
        }
        #if DEBUG
        print("\(level) \(message)")
        didLog?(message)
        #endif
    }
}

public extension MWConsoleLogger {
    /// The verbosity of log messages
    enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3

        var name: String {
            switch self {
            case .debug: return "debug"
            case .info: return "info"
            case .warning: return "warning"
            case .error: return "error"
            }
        }
    }
}

internal extension MWConsoleLoggerDelegate {

    func _didUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logWith(.error, message: "didUpdateValueForCharacteristic \(error)")
            return
        }

        let logMessage = characteristic.uuid == .metaWearNotification
        ? "Received: \(characteristic.value?.hexEncodedString() ?? "N/A")"
        : "didUpdateValueForCharacteristic \(MetaWear.Characteristic(cbuuid: characteristic.uuid)?.rawValue ?? characteristic.uuid.uuidString)"

        logWith(.info, message: logMessage)
    }
}
