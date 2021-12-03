/// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import XCTest
import Combine
import CoreBluetooth
@testable import MetaWear
@testable import MetaWearCpp

class ManualTests: XCTestCase, MetaWearTestCase {

    var device: MetaWear?
    var counter: OpaquePointer!
    var comparator: OpaquePointer!
    var id: Int!

    var expectation: XCTestExpectation?
    var counterInt: Int = 0
    var data: [MWData] = []
    
    // MARK: - Setup/Teardown - Discover, Connect, Disconnect

    var discovery: AnyCancellable? = nil
    var disconnectExpectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
        connectToAnyNearbyMetaWear()
    }

    override func tearDown() {
        super.tearDown()
        XCTAssertNoThrow(try expectDisconnection())
    }

    func testConnection() throws {
        XCTAssertTrue(device?.isConnectedAndSetup == true)
        try prepareDeviceForTesting()
    }

    // MARK: Tests A

    func testSetDeviceName() throws {
        try _wait(forVisualInspection: 2) { device, exp, _ in
            let name = "TEMPY"
            mbl_mw_settings_set_device_name(device.board, name, UInt8(name.count))
        }
    }

    func testSetDeviceNamePermanently() throws {
        try _wait(timeout: 4, exps: []) { device, exp, _ in
            let name = "TEMPY"
            mbl_mw_macro_record(device.board, 1)
            mbl_mw_settings_set_device_name(device.board, name, UInt8(name.count))
            mbl_mw_macro_end_record(device.board, bridge(obj: exp)) { (context, board, value) in
                print("macro done")
                let exp: XCTestExpectation = bridge(ptr: context!)
                exp.fulfill()
            }
        }
    }

    func testLinkSaturation() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "wait to get all")
        // Set the max range of the accelerometer
        let signal = mbl_mw_debug_get_key_register_data_signal(device.board)
        mbl_mw_datasignal_subscribe(signal,  bridgeRetained(obj: self)) { (context, dataPtr) in
            let this: ManualTests = bridge(ptr: context!)
            let val: UInt32 = dataPtr!.pointee.valueAs()
            XCTAssertEqual(this.counterInt, Int(val))
            if (this.counterInt == 1000) {
                this.expectation?.fulfill()
            }
            this.counterInt += 1
        }
        device.apiAccessQueue.async {
            self.counterInt = 1
            for i in 1...1000 {
                mbl_mw_debug_set_key_register(device.board, UInt32(i))
                mbl_mw_datasignal_read(signal)
            }
        }
        wait(for: [expectation!], timeout: 30)
    }

    func testRSSI() throws {
        try _wait(timeout: 30, exps: []) { device, exp, subs in
            device.rssiPublisher
                .sink { signal in
                    XCTAssertGreaterThan(signal, -80)
                    XCTAssertLessThan(signal, 0)
                    exp.fulfill()
                }
                .store(in: &subs)
        }
    }

    func testEuler() throws {
        let device = try XCTUnwrap(device)
        expectation = XCTestExpectation(description: "expectation")
        let accelRange = MBL_MW_SENSOR_FUSION_ACC_RANGE_16G
        let gyroRange = MBL_MW_SENSOR_FUSION_GYRO_RANGE_2000DPS
        let sensorFusionMode = MBL_MW_SENSOR_FUSION_MODE_IMU_PLUS
        mbl_mw_sensor_fusion_set_acc_range(device.board, accelRange)
        mbl_mw_sensor_fusion_set_gyro_range(device.board, gyroRange)
        mbl_mw_sensor_fusion_set_mode(device.board, sensorFusionMode)
        let eulerSignal = mbl_mw_sensor_fusion_get_data_signal(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)!
        mbl_mw_datasignal_subscribe(eulerSignal, bridge(obj: self)) { (context, dataPtr) in
            let this: ManualTests = bridge(ptr: context!)
            print(dataPtr!.pointee.valueAs() as MblMwEulerAngles)
            this.data.append(dataPtr!.pointee.copy())
        }
        mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
        mbl_mw_sensor_fusion_enable_data(device.board, MBL_MW_SENSOR_FUSION_DATA_EULER_ANGLE)
        mbl_mw_sensor_fusion_write_config(device.board)
        mbl_mw_sensor_fusion_start(device.board)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            mbl_mw_sensor_fusion_stop(device.board)
            mbl_mw_sensor_fusion_clear_enabled_mask(device.board)
            for entry in self.data {
                let pt: MblMwEulerAngles = entry.valueAs()
                print("\(pt)")
            }
            self.expectation?.fulfill()
        }
        wait(for: [expectation!], timeout: 300)
    }

    func testReadMacro() throws {
        let expectedMessages = [ // 0f82000119?
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82",
            "Received: 0f82"
        ]

        var receivedMessages = [String]()

        try _wait(timeout: 30, exps: []) { device, exp, _ in
            for i: UInt8 in 0..<8 {
                let cmd: [UInt8] = [0x0F, 0x82, i]
                mbl_mw_debug_send_command(device.board, cmd, UInt8(cmd.count))
            }

            MWConsoleLogger.shared.didLog = { string in
                guard string.hasPrefix("Received: ") else { return }
                receivedMessages.append(string)
                if receivedMessages.suffix(expectedMessages.endIndex) == expectedMessages {
                    exp.fulfill()
                }
            }
        }
    }

    // MARK: - Tests B

    func testJumpToBootloader() throws {
        let device = try XCTUnwrap(device)
        mbl_mw_debug_jump_to_bootloader(device.board)
    }

    func test_macro() {
        connectNearbyMetaWear(timeout: 360, useLogger: false
                              // requireDeviceUUID: "931C9F87-18F8-02E3-D2B4-31E9E3D34D92",
        ) { metawear, exp, subs in
            metawear
                .publish()
                .macro(executeOnBoot: false) { macro in
                    macro.command(.ledFlash(
                        color: .brown,
                        intensity: .init(1),
                        repetitions: 5,
                        duration: 5,
                        period: 1
                    )).eraseToAnyPublisher()
                }
                ._assertNoFailure(receiveValue: { macroID in
                    XCTAssertGreaterThan(macroID, 0)
                })
                .flatMap { macroID -> MWPublisher<MetaWear> in
                    metawear.publish().macroExecute(id: macroID)
                }
                .delay(for: 5, tolerance: 0, scheduler: metawear.apiAccessQueue)
                .sink(receiveCompletion: { completion in
                    guard case let .failure(error) = completion else { return }
                    XCTFail(error.localizedDescription)
                }) { _ in
                    exp.fulfill()
                }
                .store(in: &subs)
        }
    }

    func testUserMacro() throws {
        try _wait(forVisualInspection: 60) { device, exp, subs in
            exp.isInverted = false

            print("macro")
            mbl_mw_macro_record(device.board, 1)
            let switcher = mbl_mw_switch_get_state_data_signal(device.board)
            print("switch: ", switcher as Any)

            func flashLED() {

            }

            try XCTUnwrap(switcher)
                .accounterCreateCount()
                .flatMap { counter -> AnyPublisher<OpaquePointer,MWError> in
                    self.counter = counter
                    print("counter: ", counter)

                    return counter.comparatorCreate(
                        op: MBL_MW_COMPARATOR_OP_EQ,
                        mode: MBL_MW_COMPARATOR_MODE_ABSOLUTE,
                        references: [Float(2999)]
                    )
                }
                .flatMap { comparator -> AnyPublisher<Void,MWError> in
                    print("comp: ", comparator)
                    mbl_mw_event_record_commands(comparator)
                    print("led")

                    var localSubs = Set<AnyCancellable>()
                    device
                        .publish()
                        .command(.ledFlash(
                            color: .red,
                            intensity: .init(1),
                            repetitions: 1)
                        )
                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                        .store(in: &localSubs)

                    mbl_mw_dataprocessor_counter_set_state(self.counter, 0)
                    print("event end")
                    return comparator.eventEndRecording().eraseToAnyPublisher()
                }
                .flatMap { _ -> AnyPublisher<Int32,MWError> in
                    print("macro end")
                    return device.publish().flatMap { $0.board.macroEndRecording() }
                        .handleEvents(receiveOutput: { macroID in
                            let _id = Int(macroID)
                            self.id = _id
                            print("macro with id: ", _id)
                            print("macro execute")
                            mbl_mw_macro_execute(device.board, UInt8(macroID))
                        })
                        .eraseToAnyPublisher()
                }
                .sink(receiveCompletion: { completion in
                    guard case let .failure(error) = completion else { return }
                    XCTFail(error.localizedDescription)

                }, receiveValue: { _ in
                    print("done")
                    exp.fulfill()
                })
                .store(in: &subs)

        }
    }

    func testiBeacon() throws {
        try _wait(forVisualInspection: 4) { device, _, subs in
            device
                .publish()
                .command(.ledFlash(
                    color: .green,
                    intensity: .init(1),
                    repetitions: 2)
                )
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &subs)
            //mbl_mw_ibeacon_enable(device.board)
            //mbl_mw_ibeacon_set_major(device.board, 1111)
            //mbl_mw_ibeacon_set_minor(device.board, 2222)
            //        mbl_mw_debug_disconnect(device.board)
        }
    }

    // 020101
    
    func testWhitelist() throws {
        try _wait(forVisualInspection: 60) { device, _, subs in
            device
                .publish()
                .command(.ledFlash(
                    color: .green,
                    intensity: .init(1),
                    repetitions: 2)
                )
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &subs)
            var address = MblMwBtleAddress(address_type: 0, address: (0x70, 0x9e, 0x38, 0x95, 0x01, 0x00))
            mbl_mw_settings_add_whitelist_address(device.board, 0, &address)
            mbl_mw_settings_set_ad_parameters(device.board, 418, 0, MBL_MW_BLE_AD_TYPE_CONNECTED_DIRECTED)
            // mbl_mw_settings_set_whitelist_filter_mode(device.board, MBL_MW_WHITELIST_FILTER_SCAN_AND_CONNECTION_REQUESTS)
            mbl_mw_debug_disconnect(device.board)
        }
    }
    
    func testClearMacro() throws {
        try _wait(forVisualInspection: 60) { device, _, _ in
            mbl_mw_macro_erase_all(device.board)
            mbl_mw_debug_reset_after_gc(device.board)
            mbl_mw_debug_disconnect(device.board)
        }
    }
}

// MARK: - Helpers

protocol MetaWearTestCase: XCTestCase {
    var device: MetaWear? { get set }
    var discovery: AnyCancellable? { get set }
    var disconnectExpectation: XCTestExpectation? { get set }

    func connectToAnyNearbyMetaWear()
    func expectDisconnection() throws
    func prepareDeviceForTesting() throws
}

extension MetaWearTestCase {

    func connectToNearbyMetaWear(
        timeout: TimeInterval,
        invertWaitExp: Bool = false,
        exps: XCTestExpectation...,
        enforceOrder: Bool = false,
        test: @escaping (AnyPublisher<MetaWear,MWError>, inout Set<AnyCancellable>) throws -> Void
    ) throws {
        var subs = Set<AnyCancellable>()
        let didConnect = XCTestExpectation(description: "Connecting")
        self.disconnectExpectation = XCTestExpectation(description: "Disconnecting")

        scanner.startScan(allowDuplicates: true)
        try test(_makeDiscoveryPipeline(didConnect: didConnect), &subs)
        wait(for: [didConnect] + exps, timeout: timeout, enforceOrder: enforceOrder)
        device?.disconnect()
    }

    func onceConnectedToNearbyMetaWear(
        timeout: TimeInterval,
        invertWaitExp: Bool = false,
        exps: XCTestExpectation...,
        enforceOrder: Bool = false,
        test: @escaping (MetaWear, inout Set<AnyCancellable>) throws -> Void
    ) {
        let didConnect = XCTestExpectation(description: "Connecting")
        self.disconnectExpectation = XCTestExpectation(description: "Disconnecting")
        var subs = Set<AnyCancellable>()
        _makeDiscoveryPipeline(didConnect: didConnect)
            .receive(on: MetaWearScanner.sharedRestore.bleQueue)
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else { return }
                XCTFail(error.localizedDescription)
            }) { device in
                do { try test(device, &subs) }
                catch { XCTFail(error.localizedDescription) }
            }
            .store(in: &subs)

        scanner.startScan(allowDuplicates: true)
        wait(for: [didConnect] + exps, timeout: timeout, enforceOrder: enforceOrder)
        device?.disconnect()
    }

    func _makeDiscoveryPipeline(didConnect: XCTestExpectation) -> AnyPublisher<MetaWear,MWError> {
        MetaWearScanner.sharedRestore.didDiscover
            .filter { $0.rssi > -70 }
            .handleEvents(receiveOutput: {
                scanner.stopScan()
                guard (self.device === $0) == false else { return }
                self.device = $0
                self.device?.logDelegate = MWConsoleLogger.shared
            })
            .flatMap { metawear -> AnyPublisher<MetaWear,MWError> in
                return metawear.connectPublisher()
                    .handleEvents(receiveOutput: { [weak didConnect] device in
                        didConnect?.fulfill()
                        print("")
                        print("--------------------------------------------------------------------")
                        print("Connected to:", device.mac ?? "No MAC", device.peripheral.identifier.uuidString)
                        print("--------------------------------------------------------------------")
                        print("")
                    })
                    .eraseToAnyPublisher()
            }
            .subscribe(on: MetaWearScanner.sharedRestore.bleQueue, options: nil)
            .eraseToAnyPublisher()
    }
}

typealias TestHandler = (MetaWear, XCTestExpectation, inout Set<AnyCancellable>) throws -> Void

extension MetaWearTestCase {

    /// Expect that the MetaWear reports a disconnection when requested.
    ///
    func expectDisconnection() throws {
        let exp = try XCTUnwrap(disconnectExpectation)
        device?.disconnect()
        wait(for: [exp], timeout: 60)
    }

    /// Print out identifying information (and test that information is present)
    ///
    func prepareDeviceForTesting() throws {
        let device = try XCTUnwrap(device)
        print(device.mac ?? "In MetaBoot")
        print(try XCTUnwrap(device.info), device.name)
        device.resetToFactoryDefaults()
    }

    /// Connect to the first nearby MetaWear discovered with decent signal strength within 60 seconds or fails. Sets up for disconnect expectation.
    ///
    /// Split into helper methods so some methods can test cancellation.
    ///
    func connectToAnyNearbyMetaWear() {
        let didConnect = XCTestExpectation(description: "Connecting")
        self.disconnectExpectation = XCTestExpectation(description: "Disconnecting")
        self.discovery = _makeDiscoveryPipeline(didConnect: didConnect)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        scanner.startScan(allowDuplicates: true)
        wait(for: [didConnect], timeout: 20)
    }



    /// Inverted timeout for manual tests (passes w/o fulfillment)
    func _wait(forVisualInspection: TimeInterval,
               label: String = #function,
               test: @escaping TestHandler
    ) throws {
        var subs = Set<AnyCancellable>()
        let device = try XCTUnwrap(device)
        let delayForVisualSighting = XCTestExpectation(description: label)
        delayForVisualSighting.isInverted = true
        try test(device, delayForVisualSighting, &subs)
        wait(for: [delayForVisualSighting], timeout: forVisualInspection)
    }

    /// Timeout sugar
    func _wait(timeout: TimeInterval,
               invertTimeoutExp: Bool = false,
               exps: [XCTestExpectation],
               enforceOrder: Bool = false,
               label: String = #function,
               test: @escaping TestHandler
    ) throws {
        let device = try XCTUnwrap(device)
        let exp = XCTestExpectation(description: label)
        exp.isInverted = invertTimeoutExp
        var subs = Set<AnyCancellable>()
        try test(device, exp, &subs)
        wait(for: exps + [exp], timeout: timeout, enforceOrder: enforceOrder)
    }


}
