//// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.
import Combine
import CoreBluetooth
import XCTest
import MetaWear
import MetaWearCpp

@testable import MetaWearFirmware
@testable import SwiftCombineSDKTestHost

class FirmwareTests: XCTestCase {

  func testLive_FirmwareBuildFetch() {
    let waitExp = XCTestExpectation()
    var subs = Set<AnyCancellable>()
    MWFirmwareServer
      .getLatestFirmwareAsync(
        hardwareRev: "0.1",
        modelNumber: "8"
      )
      .sink(receiveCompletion: { completion in
        switch completion {
        case .failure(let error):
          XCTFail(error.localizedDescription)
          return
        case .finished:
          waitExp.fulfill()
          return
        }
      }, receiveValue: { value in

        print(value)
      })
      .store(in: &subs)
    wait(for: [waitExp], timeout: 5)
  }

  func testLive_GetFirmware() {
    connectNearbyMetaWear(timeout: .download) { metawear, exp, subs in
      MWFirmwareServer
        .fetchLatestFirmware(for: metawear)
        ._sinkNoFailure(&subs, receiveValue: { firmware in
          print(firmware)
          XCTAssertEqual(firmware.firmwareRev, "1.7.2")
          exp.fulfill()
        })
    }
  }
}
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
