// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Combine
import CoreBluetooth

/// Handles messages from MetaWear devices
///
public protocol MWConsoleLoggerDelegate: AnyObject {
    func logWith(_ level: MWConsoleLogger.LogLevel, message: String)
}

/// Prints MetaWear Bluetooth packets to the console. Singleton.
/// Set ``MWConsoleLogger/activateConsoleLoggingOnAllMetaWears`` to enroll all devices or manually set the logger in the target MetaWear.
///
public class MWConsoleLogger: MWConsoleLoggerDelegate {
    public static let shared = MWConsoleLogger()

    /// Configures this logger as the default logger for all MetaWears.
    public static let activateConsoleLoggingOnAllMetaWears = false

    internal init() {
        self.didLogPublisher = _didLog.dropFirst().eraseToAnyPublisher()
    }

    public let didLogPublisher: AnyPublisher<String,Never>
    public var didLog: ((String) -> Void)? = nil
    public var minLevel = LogLevel.info
    public var printInDebugMode = true

    public func logWith(_ level: LogLevel, message: String) {
        guard level.rawValue >= minLevel.rawValue else { return }
        let composedMessage = "\(level.name) | \(message)"
        _didLog.send(composedMessage)
        didLog?(composedMessage)
        #if DEBUG
        if printInDebugMode { print(composedMessage) }
        #endif
    }

    private let _didLog = CurrentValueSubject<String,Never>("")
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
