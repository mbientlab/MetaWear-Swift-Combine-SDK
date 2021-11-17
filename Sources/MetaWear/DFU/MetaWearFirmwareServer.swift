/**
 * FirmwareServer.swift
 * MetaWear-Swift
 *
 * Created by Stephen Schiffli on 1/9/18.
 * Copyright 2018 MbientLab Inc. All rights reserved.
 *
 * IMPORTANT: Your use of this Software is limited to those specific rights
 * granted under the terms of a software license agreement between the user who
 * downloaded the software, his/her employer (which must be your employer) and
 * MbientLab Inc, (the "License").  You may not use this Software unless you
 * agree to abide by the terms of the License which can be found at
 * www.mbientlab.com/terms.  The License limits your use, and you acknowledge,
 * that the Software may be modified, copied, and distributed when used in
 * conjunction with an MbientLab Inc, product.  Other than for the foregoing
 * purpose, you may not use, reproduce, copy, prepare derivative works of,
 * modify, distribute, perform, display or sell this Software and/or its
 * documentation for any purpose.
 *
 * YOU FURTHER ACKNOWLEDGE AND AGREE THAT THE SOFTWARE AND DOCUMENTATION ARE
 * PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTY OF MERCHANTABILITY, TITLE,
 * NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL
 * MBIENTLAB OR ITS LICENSORS BE LIABLE OR OBLIGATED UNDER CONTRACT, NEGLIGENCE,
 * STRICT LIABILITY, CONTRIBUTION, BREACH OF WARRANTY, OR OTHER LEGAL EQUITABLE
 * THEORY ANY DIRECT OR INDIRECT DAMAGES OR EXPENSES INCLUDING BUT NOT LIMITED
 * TO ANY INCIDENTAL, SPECIAL, INDIRECT, PUNITIVE OR CONSEQUENTIAL DAMAGES, LOST
 * PROFITS OR LOST DATA, COST OF PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY,
 * SERVICES, OR ANY CLAIMS BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY
 * DEFENSE THEREOF), OR OTHER SIMILAR COSTS.
 *
 * Should you have any questions regarding your right to use this Software,
 * contact MbientLab via email: hello@mbientlab.com
 */

import CoreBluetooth
import Combine

/// Possible errors when retrieving firmwares from the MbientLab servers
///
public enum FirmwareError: Error {
    /// If server is down or not responding
    case badServerResponse
    /// Unable to find a compatible firmware
    case noAvailableFirmware(_ message: String)
    /// Likely to never occur, unless device runs out of space
    case cannotSaveFile(_ message: String)
}

/// Interface with the MbientLab firmware server
///
public class MetaWearFirmwareServer {
    private init() { }
    public static let session = URLSession(configuration: .ephemeral)
}

// MARK: - Public API

/// See `MetaWear+UpdateFirmware.swift` for installation.

public extension MetaWearFirmwareServer {

    /// Get a pointer to the latest firmware for this device
    ///
    func fetchLatestFirmware(for device: MetaWear) -> AnyPublisher<FirmwareBuild,Error> {
        Publishers.Zip(device.readCharacteristic(.hardwareRevision), device.readCharacteristic(.modelNumber))
            .eraseErrorType()
            .flatMap(Self.getLatestFirmwareAsync)
            .eraseToAnyPublisher()
    }

    /// Get the latest firmware to update (if any)
    /// - Returns: Nil if already on latest, otherwise the latest build
    ///
    func fetchRelevantFirmwareUpdate(for device: MetaWear) -> AnyPublisher<FirmwareBuild?,Error> {
        Publishers.Zip(self.fetchLatestFirmware(for: device), device.readCharacteristic(.firmwareRevision).eraseErrorType())
            .map { latestBuild, boardFirmware -> FirmwareBuild? in
                boardFirmware.isMetaWearVersion(lessThan: latestBuild.firmwareRev) ? latestBuild : nil
            }
            .eraseToAnyPublisher()
    }
}

public extension MetaWearFirmwareServer {

    /// Find all compatible firmware for the given device type. Call on a background queue.
    ///
    static func getAllFirmwareAsync(hardwareRev: String,
                                    modelNumber: String,
                                    buildFlavor: String = "vanilla"
    ) -> AnyPublisher<[FirmwareBuild],Error> {

        session.dataTaskPublisher(for: Self.request())
            .tryMap(validateJSON)
            .map { _parseFirmwaresFromValidJSON($0, (hardwareRev, modelNumber, buildFlavor)) }
            .tryMap { allFirmwares in
                guard allFirmwares.endIndex > 0
                else { throw FirmwareError.noAvailableFirmware("No valid firmware releases found.  Please update your application and if problem persists, email developers@mbientlab.com") }
                return allFirmwares
            }
            .eraseToAnyPublisher()
    }

    /// Get only the most recent firmware (vanilla build flavor)
    ///
    static func getLatestFirmwareAsync(hardwareRev: String, modelNumber: String)
    -> AnyPublisher<FirmwareBuild,Error> {

        MetaWearFirmwareServer
            .getAllFirmwareAsync(hardwareRev: hardwareRev, modelNumber: modelNumber, buildFlavor: "vanilla")
            .tryMap { builds in
                guard let latest = builds.last
                else { throw FirmwareError.noAvailableFirmware("No valid firmware releases found.") }
                return latest
            }
            .eraseToAnyPublisher()
    }

    /// Find all compatible bootloaders for the given device type
    ///
    static func _getAllBootloaderAsync(hardwareRev: String,
                                       modelNumber: String
    ) -> AnyPublisher<[FirmwareBuild], Error> {

        MetaWearFirmwareServer
            .getAllFirmwareAsync(hardwareRev: hardwareRev, modelNumber: modelNumber, buildFlavor: "bootloader")
    }

    /// Get only the most recent firmware (custom build flavor)
    ///
    static func _getLatestFirmwareAsync(hardwareRev: String,
                                        modelNumber: String,
                                        buildFlavor: String)
    -> AnyPublisher<FirmwareBuild,Error> {

        MetaWearFirmwareServer
            .getAllFirmwareAsync(hardwareRev: hardwareRev, modelNumber: modelNumber, buildFlavor: buildFlavor)
            .tryMap { builds in
                guard let latest = builds.last
                else { throw FirmwareError.noAvailableFirmware("No valid firmware releases found.") }
                return latest
            }
            .eraseToAnyPublisher()
    }


    /// Try to find the the given firmware version
    ///
    static func getVersionAsync(hardwareRev: String,
                                 modelNumber: String,
                                 firmwareRev: String,
                                 buildFlavor: String = "vanilla",
                                 requiredBootloader: String? = nil
    ) -> AnyPublisher<FirmwareBuild,Error> {

        var build = FirmwareBuild(
            hardwareRev: hardwareRev,
            modelNumber: modelNumber,
            buildFlavor: buildFlavor,
            firmwareRev: firmwareRev,
            filename: "firmware.zip",
            requiredBootloader: requiredBootloader
        )

        return downloadAsync(url: build.firmwareURL)
            .catch { error -> AnyPublisher<URL,Error> in
                build = FirmwareBuild(
                    hardwareRev: hardwareRev,
                    modelNumber: modelNumber,
                    buildFlavor: buildFlavor,
                    firmwareRev: firmwareRev,
                    filename: "firmware.bin",
                    requiredBootloader: requiredBootloader
                )
                return downloadAsync(url: build.firmwareURL)
            }
            .map { _ in build }
            .eraseToAnyPublisher()
    }


    /// Use the MetaWear Firmware URLSession to download a URL to a local file
    ///
    static func downloadAsync(url: URL) -> AnyPublisher<URL,Error> {

        return MetaWearFirmwareServer.session
            .dataTaskPublisher(for: url)
#if DEBUG
            .print("MetaWear Downloading... \(url)")
#endif
            .retry(3)
            .tryMap(MetaWearFirmwareServer.validateResponse)
            .tryMap { data -> URL in
                // If no download error, then copy the file to a permanent place.  Note the location
                // variable supplied is invalid once this block returns.
                do {
                    let tempUrl = try FileManager.default.url(
                        for: .itemReplacementDirectory,
                           in: .userDomainMask,
                           appropriateFor: url,
                           create: true
                    )
                        .appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: tempUrl)
                    try data.write(to: tempUrl, options: .atomic)
#if DEBUG
                    print("Download Complete")
#endif
                    return tempUrl
                } catch {
                    throw FirmwareError.cannotSaveFile("Couldn't find temp directory to store firmware file.  Please report issue to developers@mbientlab.com")
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Internal - JSON/URLRequest Helpers

extension MetaWearFirmwareServer {

    fileprivate static func request() -> URLRequest {
        URLRequest(
            url: URL(string: "https://mbientlab.com/releases/metawear/info2.json")!,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 10
        )
    }

    @discardableResult
    fileprivate static func validateResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse
        else { throw FirmwareError.badServerResponse }

        guard httpResponse.statusCode == 200
        else { throw FirmwareError.noAvailableFirmware("\(Self.self) \(Self.request().url!) returned code \(httpResponse.statusCode)") }

        return data
    }

    fileprivate typealias JSON = [String: [String: [String: [String: [String: String]]]]]

    fileprivate static func validateJSON(data: Data, response: URLResponse) throws -> JSON {
        try validateResponse(data: data, response: response)

        guard let info = try? JSONSerialization.jsonObject(with: data) as? JSON
        else { throw FirmwareError.badServerResponse }

        return info
    }

    fileprivate static func _parseFirmwaresFromValidJSON(
        _ info: MetaWearFirmwareServer.JSON,
        _ device: (hardware: String, model: String, build: String)
    ) -> [FirmwareBuild] {

        guard let potentialVersions = info[device.hardware]?[device.model]?[device.build]
        else { return [] }

        let sdkVersion = Bundle(for: MetaWear.self).infoDictionary?["CFBundleShortVersionString"] as! String
        return potentialVersions
            .filter { sdkVersion.isMetaWearVersion(greaterThanOrEqualTo: $1["min-ios-version"]!) }
            .sorted { $0.key.isMetaWearVersion(lessThan: $1.key) }
            .map {
                FirmwareBuild(hardwareRev: device.hardware,
                              modelNumber: device.model,
                              buildFlavor: device.build,
                              firmwareRev: $0,
                              filename: $1["filename"]!,
                              requiredBootloader: $1["required-bootloader"]!)
            }

    }

}
