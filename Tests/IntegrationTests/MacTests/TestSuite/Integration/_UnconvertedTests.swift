//
//    func testReadAccelStepCounterData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "read accel step counter data")
//        mbl_mw_acc_bmi270_read_step_counter(device.board, bridge(obj: self)) { (context, board, value) in
//            print("GOT THIS:", value)
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }
//
//    func testAccelStepCounterData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "get accel step counter data")

//        mbl_mw_acc_start(device.board)
//        mbl_mw_acc_set_range(device.board, 8.0)
//        mbl_mw_acc_set_odr(device.board, 100) //Must be at least 25Hz to work features
//        mbl_mw_acc_write_acceleration_config(device.board)

//        mbl_mw_acc_bmi270_set_step_counter_trigger(device.board, 1) //every 20 steps
//        mbl_mw_acc_bmi270_write_step_counter_config(device.board)

//        mbl_mw_acc_bmi270_reset_step_counter(device.board)

//        let accStepSignal = mbl_mw_acc_bmi270_get_step_counter_data_signal(device.board) // mbl_mw_acc_bmi160_get_step_counter_data_signal
//        mbl_mw_datasignal_subscribe(accStepSignal, bridge(obj: self)) { (context, dataPtr) in
//            let this: AccelerometerTests = bridge(ptr: context!)
//            let df = DateFormatter()
//            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
//            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
//            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as UInt32)
//            this.data.append(dataPtr!.pointee.copy())
//        }
//        mbl_mw_acc_bmi270_enable_step_counter(device.board) // Start detecting motion and turn on acc

//        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
//            mbl_mw_acc_bmi270_reset_step_counter(device.board)
//            mbl_mw_acc_bmi270_disable_step_counter(device.board) // Stop the stream
//            mbl_mw_acc_stop(device.board)
//            mbl_mw_datasignal_unsubscribe(accStepSignal)
//            for entry in self.data {
//                let pt: UInt32 = entry.valueAs()
//                print("\(pt)")
//            }
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }






//    func testLinkSaturation() throws {
//        let device = try XCTUnwrap(device)
//        expectation = XCTestExpectation(description: "wait to get all")
//        // Set the max range of the accelerometer
//        let signal = mbl_mw_debug_get_key_register_data_signal(device.board)
//        mbl_mw_datasignal_subscribe(signal,  bridgeRetained(obj: self)) { (context, dataPtr) in
//            let this: ManualTests = bridge(ptr: context!)
//            let val: UInt32 = dataPtr!.pointee.valueAs()
//            XCTAssertEqual(this.counterInt, Int(val))
//            if (this.counterInt == 1000) {
//                this.expectation?.fulfill()
//            }
//            this.counterInt += 1
//        }
//        device.bleQueue.async {
//            self.counterInt = 1
//            for i in 1...1000 {
//                mbl_mw_debug_set_key_register(device.board, UInt32(i))
//                mbl_mw_datasignal_read(signal)
//            }
//        }
//        wait(for: [expectation!], timeout: 30)
//    }






//    func testReadMacro() throws {
//        let expectedMessages = [ // 0f82000119?
//            "Received: 0f82",
//            "Received: 0f82",
//            "Received: 0f82",
//            "Received: 0f82",
//            "Received: 0f82",
//            "Received: 0f82",
//            "Received: 0f82"
//        ]
//
//        var receivedMessages = [String]()
//
//        try _wait(timeout: 30, exps: []) { device, exp, _ in
//            for i: UInt8 in 0..<8 {
//                let cmd: [UInt8] = [0x0F, 0x82, i]
//                mbl_mw_debug_send_command(device.board, cmd, UInt8(cmd.count))
//            }
//
//            MWConsoleLogger.shared.didLog = { string in
//                guard string.hasPrefix("Received: ") else { return }
//                receivedMessages.append(string)
//                if receivedMessages.suffix(expectedMessages.endIndex) == expectedMessages {
//                    exp.fulfill()
//                }
//            }
//        }
//    }







//    func testUserMacro() throws {
//        try _wait(forVisualInspection: 60) { device, exp, subs in
//            exp.isInverted = false
//
//            print("macro")
//            mbl_mw_macro_record(device.board, 1)
//            let switcher = mbl_mw_switch_get_state_data_signal(device.board)
//            print("switch: ", switcher as Any)
//
//            func flashLED() {
//
//            }
//
//            try XCTUnwrap(switcher)
//                .accounterCreateCount()
//                .flatMap { counter -> AnyPublisher<OpaquePointer,MWError> in
//                    self.counter = counter
//                    print("counter: ", counter)
//
//                    return counter.comparatorCreate(
//                        op: MBL_MW_COMPARATOR_OP_EQ,
//                        mode: MBL_MW_COMPARATOR_MODE_ABSOLUTE,
//                        references: [Float(2999)]
//                    )
//                }
//                .flatMap { comparator -> AnyPublisher<Void,MWError> in
//                    print("comp: ", comparator)
//                    mbl_mw_event_record_commands(comparator)
//                    print("led")
//
//                    var localSubs = Set<AnyCancellable>()
//                    device
//                        .publish()
//                        .command(.ledFlash(
//                            color: .red,
//                            intensity: .init(1),
//                            repetitions: 1)
//                        )
//                        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
//                        .store(in: &localSubs)
//
//                    mbl_mw_dataprocessor_counter_set_state(self.counter, 0)
//                    print("event end")
//                    return comparator.eventEndRecording().eraseToAnyPublisher()
//                }
//                .flatMap { _ -> AnyPublisher<Int32,MWError> in
//                    print("macro end")
//                    return device.publish().flatMap { $0.board.macroEndRecording() }
//                        .handleEvents(receiveOutput: { macroID in
//                            let _id = Int(macroID)
//                            self.id = _id
//                            print("macro with id: ", _id)
//                            print("macro execute")
//                            mbl_mw_macro_execute(device.board, UInt8(macroID))
//                        })
//                        .eraseToAnyPublisher()
//                }
//                .sink(receiveCompletion: { completion in
//                    guard case let .failure(error) = completion else { return }
//                    XCTFail(error.localizedDescription)
//
//                }, receiveValue: { _ in
//                    print("done")
//                    exp.fulfill()
//                })
//                .store(in: &subs)
//
//        }








//    func testWhitelist() throws {
//        try _wait(forVisualInspection: 60) { device, _, subs in
//            device
//                .publish()
//                .command(.ledFlash(
//                    color: .green,
//                    intensity: .init(1),
//                    repetitions: 2)
//                )
//                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
//                .store(in: &subs)
//            var address = MblMwBtleAddress(address_type: 0, address: (0x70, 0x9e, 0x38, 0x95, 0x01, 0x00))
//            mbl_mw_settings_add_whitelist_address(device.board, 0, &address)
//            mbl_mw_settings_set_ad_parameters(device.board, 418, 0, MBL_MW_BLE_AD_TYPE_CONNECTED_DIRECTED)
//            // mbl_mw_settings_set_whitelist_filter_mode(device.board, MBL_MW_WHITELIST_FILTER_SCAN_AND_CONNECTION_REQUESTS)
//            mbl_mw_debug_disconnect(device.board)
//        }
//    }











////    func testAccelPackedData() throws {
////        let device = try XCTUnwrap(device)
////        let expectation = XCTestExpectation(description: "get accel data")
////        // Set the max range of the accelerometer
////        mbl_mw_acc_set_range(device.board, 8.0)
////        mbl_mw_acc_set_odr(device.board, 6.25)
////        mbl_mw_acc_write_acceleration_config(device.board)
////        // Get acc signal
////        let accSignal = mbl_mw_acc_bosch_get_packed_acceleration_data_signal(device.board) // same as mbl_mw_acc_get_packed_acceleration_data_signal
////        mbl_mw_datasignal_subscribe(accSignal, bridge(obj: self)) { (context, dataPtr) in
////            let this: Tests = bridge(ptr: context!)
////            print(dataPtr!.pointee.valueAs() as [MblMwCartesianFloat])
////            this.data.append(dataPtr!.pointee.copy())
////        }
////        // Start sampling and start acc
////        mbl_mw_acc_enable_acceleration_sampling(device.board)
////        mbl_mw_acc_start(device.board)
////        // Stop after 5 seconds
////        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
////            // Stop the stream
////            mbl_mw_acc_stop(device.board)
////            mbl_mw_acc_disable_acceleration_sampling(device.board)
////            mbl_mw_datasignal_unsubscribe(accSignal)
////            for entry in self.data {
////                let pt: [MblMwCartesianFloat] = entry.valueAs()
////                print("\(pt)")
////            }
////
////            expectation.fulfill()
////        }
////        wait(for: [expectation], timeout: 30)
////    }
//
//
//    func testAccelAnyMotionData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "get accel any motion data")
//        // Start the accelerometer
//        mbl_mw_acc_start(device.board)
//        // Set the max range of the accelerometer
//        mbl_mw_acc_set_range(device.board, 8.0) // Will pick closest acceptable value //mbl_mw_acc_bosch_set_range
//        mbl_mw_acc_set_odr(device.board, 100) //Must be at least 25Hz to work features //mbl_mw_acc_bmi160_set_odr //mbl_mw_acc_bmi270_set_odr //mbl_mw_acc_bma255_set_odr
//        mbl_mw_acc_write_acceleration_config(device.board) //mbl_mw_acc_bosch_write_acceleration_config
//        // Set any motion config - acc must be on for this
//        mbl_mw_acc_bosch_set_any_motion_count(device.board, UInt8(5))
//        mbl_mw_acc_bosch_set_any_motion_threshold(device.board, 170.0)
//        mbl_mw_acc_bosch_write_motion_config(device.board, MBL_MW_ACC_BOSCH_MOTION_ANYMOTION)
//        // Get any motion signal
//        let accAnyMotionSignal = mbl_mw_acc_bosch_get_motion_data_signal(device.board)
//        mbl_mw_datasignal_subscribe(accAnyMotionSignal, bridge(obj: self)) { (context, dataPtr) in
//            let this: AccelerometerTests = bridge(ptr: context!)
//            let df = DateFormatter()
//            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
//            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
//            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as UInt32)
//            this.data.append(dataPtr!.pointee.copy())
//        }
//        // Start detecting motion and turn on acc
//        mbl_mw_acc_bosch_enable_motion_detection(device.board, MBL_MW_ACC_BOSCH_MOTION_ANYMOTION)
//        // Stop after 5 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            // Stop the stream
//            mbl_mw_acc_bosch_disable_motion_detection(device.board, MBL_MW_ACC_BOSCH_MOTION_ANYMOTION)
//            // Stop the accelerometer
//            mbl_mw_acc_stop(device.board)
//            // Unsubscribe to any motion
//            mbl_mw_datasignal_unsubscribe(accAnyMotionSignal)
//            for entry in self.data {
//                let pt: UInt32 = entry.valueAs()
//                print("\(pt)")
//            }
//
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }
//
//    func testAccelNoMotionData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "get accel no motion data")
//        // Start the accelerometer
//        mbl_mw_acc_start(device.board)
//        // Set the max range of the accelerometer
//        mbl_mw_acc_set_range(device.board, 8.0)
//        mbl_mw_acc_set_odr(device.board, 100) //Must be at least 25Hz to work features
//        mbl_mw_acc_write_acceleration_config(device.board)
//        // Set any motion config - acc must be on for this
//        mbl_mw_acc_bosch_set_no_motion_count(device.board, UInt8(5))
//        mbl_mw_acc_bosch_set_no_motion_threshold(device.board, 144.0)
//        mbl_mw_acc_bosch_write_motion_config(device.board, MBL_MW_ACC_BOSCH_MOTION_NOMOTION)
//        // Get any motion signal
//        let accNoMotionSignal = mbl_mw_acc_bosch_get_motion_data_signal(device.board)
//        mbl_mw_datasignal_subscribe(accNoMotionSignal, bridge(obj: self)) { (context, dataPtr) in
//            let this: AccelerometerTests = bridge(ptr: context!)
//            let df = DateFormatter()
//            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
//            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
//            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as UInt32)
//            this.data.append(dataPtr!.pointee.copy())
//        }
//        // Start detecting motion and turn on acc
//        mbl_mw_acc_bosch_enable_motion_detection(device.board, MBL_MW_ACC_BOSCH_MOTION_NOMOTION)
//        // Stop after 5 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            // Stop the stream
//            mbl_mw_acc_bosch_disable_motion_detection(device.board, MBL_MW_ACC_BOSCH_MOTION_NOMOTION)
//            // Stop the accelerometer
//            mbl_mw_acc_stop(device.board)
//            // Unsubscribe to any motion
//            mbl_mw_datasignal_unsubscribe(accNoMotionSignal)
//            for entry in self.data {
//                let pt: UInt32 = entry.valueAs()
//                print("\(pt)")
//            }
//
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }
//
//    func testAccelSigMotionData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "get accel sig motion data")
//        // Start the accelerometer
//        mbl_mw_acc_start(device.board)
//        // Set the max range of the accelerometer
//        mbl_mw_acc_set_range(device.board, 8.0)
//        mbl_mw_acc_set_odr(device.board, 100) //Must be at least 25Hz to work features
//        mbl_mw_acc_write_acceleration_config(device.board)
//        // Set any motion config - acc must be on for this
//        mbl_mw_acc_bosch_set_sig_motion_blocksize(device.board, UInt16(250))
//        mbl_mw_acc_bosch_write_motion_config(device.board, MBL_MW_ACC_BOSCH_MOTION_SIGMOTION)
//        // Get any motion signal
//        let accSigMotionSignal = mbl_mw_acc_bosch_get_motion_data_signal(device.board)
//        mbl_mw_datasignal_subscribe(accSigMotionSignal, bridge(obj: self)) { (context, dataPtr) in
//            let this: AccelerometerTests = bridge(ptr: context!)
//            let df = DateFormatter()
//            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
//            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
//            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as UInt32)
//            this.data.append(dataPtr!.pointee.copy())
//        }
//        // Start detecting motion and turn on acc
//        mbl_mw_acc_bosch_enable_motion_detection(device.board, MBL_MW_ACC_BOSCH_MOTION_SIGMOTION)
//        // Stop after 5 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            // Stop the stream
//            mbl_mw_acc_bosch_disable_motion_detection(device.board, MBL_MW_ACC_BOSCH_MOTION_SIGMOTION)
//            // Stop the accelerometer
//            mbl_mw_acc_stop(device.board)
//            // Unsubscribe to any motion
//            mbl_mw_datasignal_unsubscribe(accSigMotionSignal)
//            for entry in self.data {
//                let pt: UInt32 = entry.valueAs()
//                print("\(pt)")
//            }
//
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }







//    func testAccelWristGestureData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "get accel wrist gesture data")
//        // Start the accelerometer
//        mbl_mw_acc_start(device.board)
//        // Set the max range of the accelerometer
//        mbl_mw_acc_set_range(device.board, 8.0)
//        mbl_mw_acc_set_odr(device.board, 100) //Must be at least 25Hz to work features
//        mbl_mw_acc_write_acceleration_config(device.board)
//        // Write the info
//        mbl_mw_acc_bmi270_wrist_gesture_armside(device.board, 0) // left arm
//        //mbl_mw_acc_bmi270_wrist_gesture_peak(device.board, 0) // TO DO
//        //mbl_mw_acc_bmi270_wrist_gesture_samples(device.board, 0) // TO DO
//        //mbl_mw_acc_bmi270_wrist_gesture_duration(device.board, 0) // TO DO
//        mbl_mw_acc_bmi270_write_wrist_gesture_config(device.board)
//        // Get gesture signal
//        let accSignal = mbl_mw_acc_bmi270_get_wrist_detector_data_signal(device.board)
//        mbl_mw_datasignal_subscribe(accSignal, bridge(obj: self)) { (context, dataPtr) in
//            let this: AccelerometerTests = bridge(ptr: context!)
//            let df = DateFormatter()
//            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
//            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
//            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as MblMwBoschGestureType)
//            let val = dataPtr!.pointee.valueAs() as MblMwBoschGestureType
//            switch MblMwAccBoschTypewrist(UInt32(val.type)) {
//                case MBL_MW_ACC_BOSCH_TYPEWRIST_GESTURE:
//                    switch MblMwAccBoschGesture(UInt32(val.gesture_code)) {
//                        case MBL_MW_ACC_BOSCH_GESTURE_UNKNOWN:
//                                print("unknown")
//                        case MBL_MW_ACC_BOSCH_GESTURE_PUSH_ARM_DOWN:
//                                print("push arm down")
//                        case MBL_MW_ACC_BOSCH_GESTURE_PIVOT_UP:
//                                print("pivot up")
//                        case MBL_MW_ACC_BOSCH_GESTURE_SHAKE:
//                                print("shake")
//                        case MBL_MW_ACC_BOSCH_GESTURE_ARM_FLICK_IN:
//                                print("arm flick in")
//                        case MBL_MW_ACC_BOSCH_GESTURE_ARM_FLICK_OUT:
//                                print("arm flick out")
//                        default:
//                                print("none")
//                    }
//                case MBL_MW_ACC_BOSCH_TYPEWRIST_WEARK_WAKEUP:
//                    print("wrist wakeup")
//                default:
//                    print("none")
//            }
//            this.data.append(dataPtr!.pointee.copy())
//        }
//        // Start detecting motion and turn on acc
//        mbl_mw_acc_bmi270_enable_wrist_gesture(device.board)
//        // Stop after 5 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
//            // Stop the stream
//            mbl_mw_acc_bmi270_disable_wrist_gesture(device.board)
//            // Stop the accelerometer
//            mbl_mw_acc_stop(device.board)
//            // Unsubscribe to any motion
//            mbl_mw_datasignal_unsubscribe(accSignal)
//            for entry in self.data {
//                let pt: MblMwBoschGestureType = entry.valueAs()
//                print("\(pt)")
//            }
//
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }
//
//    func testAccelWristWakeupData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "get accel wrist gesture data")
//        // Start the accelerometer
//        mbl_mw_acc_start(device.board)
//        // Set the max range of the accelerometer
//        mbl_mw_acc_set_range(device.board, 8.0)
//        mbl_mw_acc_set_odr(device.board, 100) //Must be at least 25Hz to work features
//        mbl_mw_acc_write_acceleration_config(device.board)
//        // Write the info
//        //mbl_mw_acc_bmi270_wrist_wakeup_angle_focus // TO DO
//        //mbl_mw_acc_bmi270_wrist_wakeup_angle_nonfocus // TO DO
//        //mbl_mw_acc_bmi270_wrist_wakeup_tilt_lr // TO DO
//        //mbl_mw_acc_bmi270_wrist_wakeup_tilt_ll // TO DO
//        //mbl_mw_acc_bmi270_wrist_wakeup_tilt_pd // TO DO
//        //mbl_mw_acc_bmi270_wrist_wakeup_tilt_pu // TO DO
//        mbl_mw_acc_bmi270_write_wrist_wakeup_config(device.board)
//        // Get gesture signal
//        let accSignal = mbl_mw_acc_bmi270_get_wrist_detector_data_signal(device.board)
//        mbl_mw_datasignal_subscribe(accSignal, bridge(obj: self)) { (context, dataPtr) in
//            let this: AccelerometerTests = bridge(ptr: context!)
//            let df = DateFormatter()
//            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
//            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
//            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as MblMwBoschGestureType)
//            let val = dataPtr!.pointee.valueAs() as MblMwBoschGestureType
//            switch MblMwAccBoschTypewrist(UInt32(val.type)) {
//                case MBL_MW_ACC_BOSCH_TYPEWRIST_GESTURE:
//                    switch MblMwAccBoschGesture(UInt32(val.gesture_code)) {
//                        case MBL_MW_ACC_BOSCH_GESTURE_UNKNOWN:
//                                print("unknown")
//                        case MBL_MW_ACC_BOSCH_GESTURE_PUSH_ARM_DOWN:
//                                print("push arm down")
//                        case MBL_MW_ACC_BOSCH_GESTURE_PIVOT_UP:
//                                print("pivot up")
//                        case MBL_MW_ACC_BOSCH_GESTURE_SHAKE:
//                                print("shake")
//                        case MBL_MW_ACC_BOSCH_GESTURE_ARM_FLICK_IN:
//                                print("arm flick in")
//                        case MBL_MW_ACC_BOSCH_GESTURE_ARM_FLICK_OUT:
//                                print("arm flick out")
//                        default:
//                                print("none")
//                    }
//                case MBL_MW_ACC_BOSCH_TYPEWRIST_WEARK_WAKEUP:
//                    print("wrist wakeup")
//                default:
//                    print("none")
//            }
//            this.data.append(dataPtr!.pointee.copy())
//        }
//        // Start detecting motion and turn on acc
//        mbl_mw_acc_bmi270_enable_wrist_wakeup(device.board)
//        // Stop after 5 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
//            // Stop the stream
//            mbl_mw_acc_bmi270_disable_wrist_wakeup(device.board)
//            // Stop the accelerometer
//            mbl_mw_acc_stop(device.board)
//            // Unsubscribe to any motion
//            mbl_mw_datasignal_unsubscribe(accSignal)
//            for entry in self.data {
//                let pt: MblMwBoschGestureType = entry.valueAs()
//                print("\(pt)")
//            }
//
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }









//    func testAccelActivityData() throws {
//        let device = try XCTUnwrap(device)
//        let expectation = XCTestExpectation(description: "get accel activity data")
//        // Start the accelerometer
//        mbl_mw_acc_start(device.board)
//        // Set the max range of the accelerometer
//        mbl_mw_acc_set_range(device.board, 8.0)
//        mbl_mw_acc_set_odr(device.board, 100) //Must be at least 25Hz to work features
//        mbl_mw_acc_write_acceleration_config(device.board)
//        // Get gesture signal
//        let accSignal = mbl_mw_acc_bmi270_get_activity_detector_data_signal(device.board)
//        mbl_mw_datasignal_subscribe(accSignal, bridge(obj: self)) { (context, dataPtr) in
//            let this: AccelerometerTests = bridge(ptr: context!)
//            let df = DateFormatter()
//            df.dateFormat = "y-MM-dd H:m:ss.SSSS"
//            let date = df.string(from: dataPtr!.pointee.timestamp) // -> "2016-11-17 17:51:15.1720"
//            print(dataPtr!.pointee.epoch, date, dataPtr!.pointee.valueAs() as UInt32)
//            this.data.append(dataPtr!.pointee.copy())
//        }
//        // Start detecting motion and turn on acc
//        mbl_mw_acc_bmi270_enable_activity_detection(device.board)
//        // Stop after 5 seconds
//        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
//            // Stop the stream
//            mbl_mw_acc_bmi270_disable_activity_detection(device.board)
//            // Stop the accelerometer
//            mbl_mw_acc_stop(device.board)
//            // Unsubscribe to any motion
//            mbl_mw_datasignal_unsubscribe(accSignal)
//            for entry in self.data {
//                let pt: UInt32 = entry.valueAs()
//                print("\(pt)")
//            }
//
//            expectation.fulfill()
//        }
//        wait(for: [expectation], timeout: 30)
//    }
//
//}
