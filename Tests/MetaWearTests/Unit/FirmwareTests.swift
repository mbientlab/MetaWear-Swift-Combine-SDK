//// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.
//
//import XCTest
//@testable import MetaWear
//@testable import MetaWearCpp
//
//class FirmwareTests: XCTestCase {
//
//    func testFirmwareUpdateManager() {
//        let myExpectation = XCTestExpectation(description: "getting info1")
//        MWFirmwareServer.getAllFirmwareAsync(hardwareRev: "0.1", modelNumber: "0")
//            .flatMap { firmwares in
//                let exps = [
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.0.4/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.1.0/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.1.1/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.1.2/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.1.3/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.2.3/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.2.4/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.2.5/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.3.4/firmware.bin",
//                    "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.3.6/firmware.bin"
//                ]
//                zip(firmwares, exps, firmwares.indices) { (result, exp, index) in
//                    XCTAssertEqual(result.firmwareURL.absoluteString, exp)
//                    XCTAssertEqual(result.firmwareURL.absoluteString, exp, "\(index)")
//                }
//            }
//
//
//        FirmwareServer.getAllFirmwareAsync(hardwareRev: "0.1", modelNumber: "0").continueOnSuccessWithTask { result -> Task<FirmwareBuild> in
//
//            return FirmwareServer.getLatestFirmwareAsync(hardwareRev: "0.1", modelNumber: "0")
//        }.continueOnSuccessWithTask { result -> Task<URL> in
//            XCTAssertEqual(result.firmwareURL.absoluteString,
//                           "https://mbientlab.com/releases/metawear/0.1/0/vanilla/1.3.6/firmware.bin")
//            return result.firmwareURL.downloadAsync()
//        }.continueWith { t in
//            XCTAssertFalse(t.faulted)
//            XCTAssertNil(t.error)
//            myExpectation.fulfill()
//        }
//        wait(for: [myExpectation], timeout: 60)
//    }
//
//    func testGetAllFirmwareAsync() {
//        let myExpectation = XCTestExpectation(description: "getting info1")
//
//        FirmwareServer.getAllFirmwareAsync(hardwareRev: "0.2", modelNumber: "18").continueOnSuccessWith { result in
//            XCTAssertEqual(result[0].firmwareURL.absoluteString,
//                           "https://mbientlab.com/releases/metawear/0.2/18/vanilla/1.4.0/firmware.zip")
//            XCTAssertEqual(result[1].firmwareURL.absoluteString,
//                           "https://mbientlab.com/releases/metawear/0.2/18/vanilla/1.4.1/firmware.zip")
//            XCTAssertEqual(result[2].firmwareURL.absoluteString,
//                           "https://mbientlab.com/releases/metawear/0.2/18/vanilla/1.18.0/firmware.zip")
//        }.continueWith { t in
//            XCTAssertFalse(t.faulted)
//            XCTAssertNil(t.error)
//            myExpectation.fulfill()
//        }
//        wait(for: [myExpectation], timeout: 60)
//    }
//}
