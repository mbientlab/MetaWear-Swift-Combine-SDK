// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp
@testable import SwiftCombineSDKTestHost

extension XCTestCase {

    /// Connects and disconnects a nearby MetaWear for up to the specified time duration.
    /// For console output brevity, logs prior to connection are silenced.
    ///
    /// - Parameters:
    ///   - exps: Additional expectations after didConnect and before the final exp (provided in closure's middle two arguments)
    ///   - enforceOrder: Execute exps in order
    ///   - timeout: Maximum time for test closure
    ///   - invertFinalExp: Set true to hold the test open for the full time, passing if the final exp is never fulfilled
    ///   - useLogger: Print device logs to console after connection
    ///   - label: Message for the final XCTestExpectation
    ///   - test: Closure with the connected MetaWear, the final exp, a convenience for fulfilling the exp if no error, and a subscription token bag
    ///
    func connectNearbyMetaWear(
        exps: [XCTestExpectation] = [],
        enforceOrder: Bool = false,
        timeout: TimeInterval,
        invertFinalExp: Bool = false,
        useLogger: Bool = true,
        label: String = #function,
        file: StaticString = #file,
        line: UInt = #line,
        requireDeviceUUID: String? = TestDevices.current?.getTestTargetLocalUUID(),
        test: @escaping (MetaWear, XCTestExpectation, inout Set<AnyCancellable>) throws -> Void
    ) {
        self.continueAfterFailure = true
        var _connection = Set<AnyCancellable>()
        var subs = Set<AnyCancellable>()
        var metawear: MetaWear? = nil
        let didConnect = XCTestExpectation(description: "Connecting")
        let final = XCTestExpectation(description: label)
        final.isInverted = invertFinalExp

        _connectToDiscoveredDevice(didConnect: didConnect, useLogger: useLogger, requireDeviceUUID: requireDeviceUUID)
            .receive(on: Host.scanner.bleQueue)
            .subscribe(on: Host.scanner.bleQueue)
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else { return }
                XCTFail(error.localizedDescription, file: file, line: line)
            }) { device in
                metawear = device
                do { try test(device, final, &subs) }
                catch { XCTFail(error.localizedDescription, file: file, line: line) }
            }
            .store(in: &_connection)

        Host.scanner.startScan(higherPerformanceMode: true)
        wait(for: [didConnect] + exps + [final], timeout: timeout, enforceOrder: enforceOrder)
        _disconnectAfterDelay(metawear)
    }

    /// Simulate real usage where a command's complete would not instantly trigger a disconnect.
    /// Without doing so, some operations may be interrupted and not properly complete.
    ///
    func _disconnectAfterDelay(_ metawear: MetaWear?) {
        let delayDisconnect = XCTestExpectation(description: "Disconnect")
        delayDisconnect.isInverted = true
        self.continueAfterFailure = true
        wait(for: [delayDisconnect], timeout: 1)
        metawear?.disconnect()
        print("")
        print("")
    }

    func _connectToDiscoveredDevice(
        didConnect: XCTestExpectation,
        useLogger: Bool,
        requireDeviceUUID: String? = TestDevices.current?.getTestTargetLocalUUID()
    ) -> AnyPublisher<MetaWear,MWError> {

        _didDiscover(requireDeviceUUID: requireDeviceUUID)
            .flatMap { metawear -> AnyPublisher<MetaWear,MWError> in
                metawear.connect()
                return metawear
                    .publishWhenConnected()
                    .first()
                    .mapToMWError()
                    .handleEvents(receiveOutput: { [weak didConnect] device in
                        didConnect?.fulfill()
                        announce(device: device)
                        if useLogger { device.logDelegate = MWConsoleLogger.shared }
                    })
                    .eraseToAnyPublisher()
            }
            .subscribe(on: Host.scanner.bleQueue, options: nil)
            .eraseToAnyPublisher()
    }

    /// Resets connect interrupts to zero to avoid shared cross-test state. Also prints new lines at the start of test console output.
    ///
    func _didDiscover(requireDeviceUUID: String? = TestDevices.current?.getTestTargetLocalUUID()) -> MWPublisher<MetaWear> {
        print("")
        print("")
        var nonMatchesFound = Set<CBPeripheralIdentifier>()

        var device: MWPublisher<MetaWear> {
            if let id = requireDeviceUUID,
               let target = Host.scanner.discoveredDevices[.init(uuidString: id)!] {
                return _JustMW(target)
            } else {
                return Host.scanner.didDiscover
                    .filter {
                        guard let required = requireDeviceUUID else { return true }
                        let isMatch = $0.localBluetoothID == UUID(uuidString: required)
                        if !isMatch, nonMatchesFound.contains($0.localBluetoothID) == false {
                            print("Found \($0.name). This devices was excluded from use by TestDevices.useOnly()")
                            nonMatchesFound.insert($0.localBluetoothID)
                        }
                        return isMatch
                    }
                    .filter {
                        if $0.rssi < minimumRSSI { print("Low RSSI \($0.rssi) \($0.peripheral.identifier.uuidString)") }
                        return $0.rssi >= minimumRSSI
                    }
                    .first()
                    .mapToMWError()
                    .eraseToAnyPublisher()
            }
        }

        return device
            .handleEvents(receiveOutput: { metawear in
                Host.scanner.stopScan()
                metawear._connectInterrupts = 0
            })
            .eraseToAnyPublisher()
    }

    /// Setup a test with a specific MetaWear, but don't connect to it.
    ///
    func _setupWithDevice(_ uuid: String? = TestDevices.current?.getTestTargetLocalUUID(),
                          file: StaticString = #file,
                          line: UInt = #line
    ) throws -> (subs: Set<AnyCancellable>, metawear: MetaWear) {
        let expFindsDevice   = XCTestExpectation(description: "Find Device")
        var subs = Set<AnyCancellable>()
        var _device: MetaWear? = nil

        _didDiscover()
            ._sinkNoFailure(&subs, receiveValue: {
                _device = $0
                expFindsDevice.fulfill()
            })
        Host.scanner.startScan(higherPerformanceMode: true)
        wait(for: [expFindsDevice], timeout: 30)
        let metawear = try XCTUnwrap(_device, file: file, line: line)
        return (subs, metawear)
    }
}

// MARK: - Print Helpers

func _printProgress(_ percentComplete: Double) {
    print(">>", String(mwPercent: percentComplete))
}

fileprivate func announce(device: MetaWear) {
    print("")
    print("--------------------------------------------------------------------")
    print("Connected to:", device.info.mac , device.peripheral.identifier.uuidString)
    print("--------------------------------------------------------------------")
    print("")
}
