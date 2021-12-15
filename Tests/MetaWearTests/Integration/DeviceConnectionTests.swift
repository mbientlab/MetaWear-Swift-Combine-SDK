// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class DeviceConnectionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TestDevices.useOnly(.S_A4)
        self.continueAfterFailure = true
    }

    // MARK: - Connect / ConnectionStatePublisher

    func test_Connects_Once() throws {
        let exps = makeExpectations()
        var (subs, metawear) = try _setupWithDevice()

        metawear.connectionStatePublisher
            ._assertStep { step in

                if step(1, .disconnected) {
                    exps.unconnected.fulfill()
                    metawear.connect()
                } else if step(nil, .disconnected) { XCTFail("Should not disconnect") }

                if step(2, .connecting)         { exps.connecting.fulfill() }
                if step(3, .connected)          { exps.didConnect.fulfill() }
                else if step(nil, .connected)   { XCTFail("Should not reconnect") }
                if step(nil, .disconnecting)    { XCTFail("Should not disconnect") }
            }
            .store(in: &subs)

        wait(for: [exps.unconnected, exps.connecting, exps.didConnect], timeout: .download, enforceOrder: true)
        subs.forEach { $0.cancel() }
        _disconnectAfterDelay(metawear)
    }

    // MARK: - Disconnect / ConnectionStatePublisher

    func test_Disconnect_WhenConnected() throws {
        let exps = makeExpectations()
        var (subs, metawear) = try _setupWithDevice()

        metawear.connectionStatePublisher
            ._assertStep { step in

                if step(1, .disconnected) {
                    exps.unconnected.fulfill()
                    metawear.connect()
                }

                if step(2, .connecting)         { exps.connecting.fulfill() }

                if step(3, .connected) {
                    exps.didConnect.fulfill()
                    metawear.disconnect()

                } else if step(nil, .connected) { XCTFail("Should not reconnect") }
                if step(4, .disconnecting)      { exps.disconnecting.fulfill() }
                if step(5, .disconnected)       { exps.didCancel.fulfill() }
            }
            .store(in: &subs)

        wait(for: [exps.unconnected, exps.connecting, exps.didConnect, exps.disconnecting, exps.didCancel], timeout: .download, enforceOrder: true)
        _disconnectAfterDelay(metawear)
    }

    func test_CancelPendingConnection_DirectlyAfterConnectCommand_NeverConnects() throws {
        let exps = makeExpectations()
        var (subs, metawear) = try _setupWithDevice()

        metawear.connectionStatePublisher
            ._assertStep { step in

                if step(1, .disconnected) {
                    exps.unconnected.fulfill()
                    metawear.connect()
                    metawear.disconnect()
                }

                if step(2, .connecting)    { exps.connecting.fulfill() }
                if step(3, .disconnecting) { exps.disconnecting.fulfill() }
                if step(4, .disconnected)  { exps.didCancel.fulfill() }
                if step(nil, .connected)   { XCTFail("Should not connect") }
            }
            .store(in: &subs)

        wait(for: [exps.unconnected, exps.connecting, exps.disconnecting, exps.didCancel], timeout: .download, enforceOrder: true)
        _disconnectAfterDelay(metawear)
    }

    func test_CancelPendingConnection_ViaCommand_NeverConnects() throws {
        let exps = makeExpectations()
        var (subs, metawear) = try _setupWithDevice()

        metawear.connectionStatePublisher
            ._assertStep { step in

                if step(1, .disconnected) {
                    exps.unconnected.fulfill()
                    metawear.connect()
                }

                if step(2, .connecting) {
                    exps.connecting.fulfill()
                    metawear.disconnect()
                }

                if step(3, .disconnecting) { exps.disconnecting.fulfill() }
                if step(4, .disconnected)  { exps.didCancel.fulfill() }
                if step(nil, .connected)   { XCTFail("Should not connect") }
            }
            .store(in: &subs)

        wait(for: [exps.unconnected, exps.connecting, exps.disconnecting, exps.didCancel], timeout: .download, enforceOrder: true)
        _disconnectAfterDelay(metawear)
    }

    func test_CancelPendingConnection_ViaCommand_WithDelay_NeverConnects() throws {
        let exps = makeExpectations()
        var (subs, metawear) = try _setupWithDevice()

        metawear.connectionStatePublisher
            ._assertStep { step in

                if step(1, .disconnected) {
                    exps.unconnected.fulfill()
                    metawear.connect()
                }

                if step(2, .connecting) {
                    exps.connecting.fulfill()
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05) {
                        metawear.disconnect()
                    }
                }

                if step(3, .disconnecting) { exps.disconnecting.fulfill() }
                if step(4, .disconnected)  { exps.didCancel.fulfill() }
                if step(nil, .connected)   { XCTFail("Should not connect") }
            }
            .store(in: &subs)

        wait(for: [exps.unconnected, exps.connecting, exps.disconnecting, exps.didCancel], timeout: .download, enforceOrder: true)
        _disconnectAfterDelay(metawear)
    }

    func test_CancelPendingConnection_ViaScanner_WithDelay_NeverConnects() throws {
        let exps = makeExpectations()
        var (subs, metawear) = try _setupWithDevice()

        metawear.connectionStatePublisher
            ._assertStep { step in

                if step(1, .disconnected) {
                    exps.unconnected.fulfill()

                    // Act: Use scanner to force a connection, then cancel it contemporaneously
                    metawear.scanner.startScan(higherPerformanceMode: false)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05) {
                        metawear.disconnect()
                    }
                }

                if step(2, .disconnected)     { exps.didCancel.fulfill() }
                if step(nil, .disconnecting)  { XCTFail("Should not report disconnecting") }
                if step(nil, .connecting)     { XCTFail("Should not try to connect") }
                if step(nil, .connected)      { XCTFail("Should not connect") }
            }
            .store(in: &subs)

        wait(for: [exps.unconnected, exps.didCancel], timeout: .download, enforceOrder: true)
        _disconnectAfterDelay(metawear)
    }
}

// MARK: - Connection State Helpers

fileprivate extension Publisher where Output == CBPeripheralState, Failure == Never {

    func _assertStep(_ event: @escaping ( (Int?,CBPeripheralState) -> Bool ) -> Void) -> AnyCancellable {
        var steps = 0
        return self.sink { state in
            steps += 1

            func stateIs(step: Int?, _ exp: CBPeripheralState) -> Bool {
                if step == nil { return state == exp }
                else { return state == exp && steps == step }
            }

            Swift.print("->", steps, state.debugDescription)
            event(stateIs)
        }
    }
}

fileprivate func makeExpectations() -> (unconnected: XCTestExpectation, connecting: XCTestExpectation, disconnecting: XCTestExpectation, didCancel: XCTestExpectation, didConnect: XCTestExpectation) {
    let unconnected   = XCTestExpectation(description: "Initially disconnected")
    let connecting    = XCTestExpectation(description: "Is connecting")
    let disconnecting = XCTestExpectation(description: "Is disconnecting")
    let didCancel     = XCTestExpectation(description: "Did disconnect")
    let didConnect    = XCTestExpectation(description: "Did connect")
    return (unconnected, connecting, disconnecting, didCancel, didConnect)
}
