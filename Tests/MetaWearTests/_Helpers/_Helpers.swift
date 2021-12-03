// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import XCTest
@testable import MetaWear
@testable import MetaWearCpp
import Combine
import CoreBluetooth


// MARK: - Assert Async

extension Publisher {

    func _assertNoFailure(_ file: StaticString = #file,
                          _ line: UInt = #line,
                          finished: @escaping () -> Void = { },
                          receiveValue: @escaping ((Self.Output) -> Void) = { _ in }
    ) -> AnyPublisher<Output,Failure> {

        handleEvents(receiveOutput: receiveValue, receiveCompletion: { completion in
            switch completion {
                case .failure(let error):
                    XCTFail(error.localizedDescription, file: file, line: line)
                case .finished: break
            }
            finished()
        })
            .eraseToAnyPublisher()
    }

    func _sinkNoFailure(_ subs: inout Set<AnyCancellable>,
                        _ file: StaticString = #file,
                        _ line: UInt = #line,
                        finished: @escaping () -> Void = { },
                        receiveValue: @escaping (Self.Output) -> Void = { _ in }
    ) {

        sink(receiveCompletion: { completion in
            switch completion {
                case .failure(let error):
                    XCTFail(error.localizedDescription, file: file, line: line)
                case .finished: break
            }
            finished()
        }, receiveValue: receiveValue)
            .store(in: &subs)
    }

    func _sinkExpectFailure(_ subs: inout Set<AnyCancellable>,
                            _ file: StaticString = #file,
                            _ line: UInt = #line,
                            exp: XCTestExpectation,
                            errorMessage: String
    ) {

        sink(receiveCompletion: { completion in
            switch completion {
                case .failure(let error):
                    XCTAssertEqual(error.localizedDescription, errorMessage, file: file, line: line)
                    exp.fulfill()

                case .finished:
                    XCTFail("Expected to fail", file: file, line: line)
            }
        }, receiveValue: { _ in XCTFail("Expected to fail", file: file, line: line) })
            .store(in: &subs)
    }
}

// MARK: - Loggers

extension Publisher {

    func _assertLoggers(_ loggers: [MWLogger],
                        metawear: MetaWear,
                        _ file: StaticString = #file,
                        _ line: UInt = #line
    ) -> AnyPublisher<Output,MWError> {

        mapToMetaWearError()
            .flatMap { output -> AnyPublisher<Output,MWError> in
                metawear.publish()
                    .collectAnonymousLoggerSignals()
                    .map { result -> Output in
                        Swift.print("Loggers found: ", result.map(\.id.name))
                        XCTAssertEqual(loggers.count, result.count, file: file, line: line)
                        XCTAssertEqual(Set(loggers), Set(result.map(\.id)), file: file, line: line)
                        return output
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Organize Async Test

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
        requireDeviceUUID: String? = TestDevices.current?.rawValue,
        test: @escaping (MetaWear, XCTestExpectation, inout Set<AnyCancellable>) throws -> Void
    ) {
        self.continueAfterFailure = false
        var _connection = Set<AnyCancellable>()
        var subs = Set<AnyCancellable>()
        var metawear: MetaWear? = nil
        let didConnect = XCTestExpectation(description: "Connecting")
        let final = XCTestExpectation(description: label)
        final.isInverted = invertFinalExp

        _connectToDiscoveredDevice(didConnect: didConnect, useLogger: useLogger, requireDeviceUUID: requireDeviceUUID)
            .receive(on: MetaWearScanner.sharedRestore.bleQueue)
            .subscribe(on: MetaWearScanner.sharedRestore.bleQueue)
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else { return }
                XCTFail(error.localizedDescription, file: file, line: line)
            }) { device in
                metawear = device
                do { try test(device, final, &subs) }
                catch { XCTFail(error.localizedDescription, file: file, line: line) }
            }
            .store(in: &_connection)

        scanner.startScan(allowDuplicates: true)
        wait(for: [didConnect] + exps + [final], timeout: timeout, enforceOrder: enforceOrder)
        _disconnectAfterDelay(metawear)
    }

    /// Simulate real usage where a command's complete would not instantly trigger a disconnect.
    /// Without doing so, some operations may be interrupted and not properly complete.
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
        requireDeviceUUID: String? = TestDevices.current?.rawValue
    ) -> AnyPublisher<MetaWear,MWError> {

        _didDiscover(requireDeviceUUID: requireDeviceUUID)
            .flatMap { metawear -> AnyPublisher<MetaWear,MWError> in
                metawear.connect()
                return metawear
                    .publishWhenConnected()
                    .first()
                    .mapToMetaWearError()
                    .handleEvents(receiveOutput: { [weak didConnect] device in
                        didConnect?.fulfill()
                        announce(device: device)
                        if useLogger { device.logDelegate = MWConsoleLogger.shared }
                    })
                    .eraseToAnyPublisher()
            }
            .subscribe(on: MetaWearScanner.sharedRestore.bleQueue, options: nil)
            .eraseToAnyPublisher()
    }

    /// Resets connect interrupts to zero to avoid shared cross-test state. Also prints new lines at the start of test console output.
    ///
    func _didDiscover(requireDeviceUUID: String? = TestDevices.current?.rawValue) -> MWPublisher<MetaWear> {
        print("")
        print("")

        var device: MWPublisher<MetaWear> {
            if let id = requireDeviceUUID,
               let target = MetaWearScanner.sharedRestore.deviceMap[.init(uuidString: id)!] {
                return _JustMW(target)
            } else {
                return MetaWearScanner.sharedRestore.didDiscover
                    .filter { requireDeviceUUID == nil || $0.peripheral.identifier == UUID(uuidString: requireDeviceUUID!) }
                    .filter {
                        if $0.rssi < minimumRSSI { print("Low RSSI \($0.rssi) \($0.peripheral.identifier.uuidString)") }
                        return $0.rssi >= minimumRSSI
                    }
                    .first()
                    .mapToMetaWearError()
                    .eraseToAnyPublisher()
            }
        }

        return device
            .handleEvents(receiveOutput: { metawear in
                scanner.stopScan()
                metawear._connectInterrupts = 0
            })
            .eraseToAnyPublisher()
    }

    /// Setup a test with a specific MetaWear, but don't connect to it.
    ///
    func _setupWithDevice(_ uuid: String? = TestDevices.current?.rawValue,
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
        scanner.startScan(allowDuplicates: true)
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
    print("Connected to:", device.mac ?? "No MAC", device.peripheral.identifier.uuidString)
    print("--------------------------------------------------------------------")
    print("")
}
