// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import Combine
import iOSDFULibrary
import MetaWearCpp

/// Interface with the MbientLab firmware server
///
public class MWFirmwareServer {
    private init() { }
    public static let session = URLSession(configuration: .ephemeral)
}

// MARK: - Public API — Perform Firmware Update

public extension MWFirmwareServer {

    /// Install the provided firmware (or latest if none provided)
    ///
    func updateFirmware(on device: MetaWear, delegate: DFUProgressDelegate? = nil, build: MWFirmwareServer.Build? = nil) -> AnyPublisher<Void,Swift.Error> {

        // Proceed with a connection
        device
            .connectPublisher()
            .eraseErrorType()

        // Use provided or default to latest firmware
            .flatMap { [weak self, weak device] _ -> AnyPublisher<MWFirmwareServer.Build, Swift.Error> in
                guard let self = self, let device = device
                else { return _Fail(.operationFailed("Self/device unavailable")) }

                if let build = build { return _Just(build) }
                else { return self.fetchLatestFirmware(for: device) }
            }

        // Ensure in MetaBoot mode
            .flatMap { [weak device, weak delegate] build -> AnyPublisher<Void,Swift.Error> in
                guard let device = device
                else { return _Fail(.operationFailed("Device unavailable")) }

                let isInMetaBoot = device.isMetaBoot
                if isInMetaBoot == false { mbl_mw_debug_jump_to_bootloader(device.board) }
                return _updateMetaBoot(device, build, delegate)
                    .delay(for: isInMetaBoot ? 3.0 : 0, tolerance: 0, scheduler: device.apiAccessQueue, options: nil)
                    .eraseToAnyPublisher()
            }

        // Cleanup after Nordic delegate completes its cached subject or if _updateMetaBoot_ helpers can't find appropriate firmware.
            .handleEvents(receiveCompletion: { [weak device] _ in
                guard let device = device else { return }
                device.disconnect()
                initiatorCache.removeValue(forKey: device)
                dfuSourceCache.removeValue(forKey: device)
                dfuControllerCache.removeValue(forKey: device)
            })
            .eraseToAnyPublisher()
    }
}

// MARK: - Public API — Find Relevant Firmware

public extension MWFirmwareServer {

    /// Get a pointer to the latest firmware for this device
    ///
    func fetchLatestFirmware(for device: MetaWear) -> AnyPublisher<MWFirmwareServer.Build,Swift.Error> {
        Publishers.Zip(device.readCharacteristic(.hardwareRevision), device.readCharacteristic(.modelNumber))
            .eraseErrorType()
            .flatMap(Self.getLatestFirmwareAsync)
            .eraseToAnyPublisher()
    }

    /// Get the latest firmware to update (if any)
    /// - Returns: Nil if already on latest, otherwise the latest build
    ///
    func fetchRelevantFirmwareUpdate(for device: MetaWear) -> AnyPublisher<MWFirmwareServer.Build?,Swift.Error> {
        Publishers.Zip(self.fetchLatestFirmware(for: device), device.readCharacteristic(.firmwareRevision).eraseErrorType())
            .map { latestBuild, boardFirmware -> MWFirmwareServer.Build? in
                boardFirmware.isMetaWearVersion(lessThan: latestBuild.firmwareRev) ? latestBuild : nil
            }
            .eraseToAnyPublisher()
    }
}

public extension MWFirmwareServer {

    /// Find all compatible firmware for the given device type. Call on a background queue.
    ///
    static func getAllFirmwareAsync(hardwareRev: String,
                                    modelNumber: String,
                                    buildFlavor: String = "vanilla"
    ) -> AnyPublisher<[MWFirmwareServer.Build],Swift.Error> {

        session.dataTaskPublisher(for: Self.request())
            .tryMap(validateJSON)
            .map { _parseFirmwaresFromValidJSON($0, (hardwareRev, modelNumber, buildFlavor)) }
            .tryMap { allFirmwares in
                guard allFirmwares.endIndex > 0
                else { throw MWFirmwareServer.Error.noAvailableFirmware("No valid firmware releases found.  Please update your application and if problem persists, email developers@mbientlab.com") }
                return allFirmwares
            }
            .eraseToAnyPublisher()
    }

    /// Get only the most recent firmware (vanilla build flavor)
    ///
    static func getLatestFirmwareAsync(hardwareRev: String, modelNumber: String)
    -> AnyPublisher<MWFirmwareServer.Build,Swift.Error> {

        MWFirmwareServer
            .getAllFirmwareAsync(hardwareRev: hardwareRev, modelNumber: modelNumber, buildFlavor: "vanilla")
            .tryMap { builds in
                guard let latest = builds.last
                else { throw MWFirmwareServer.Error.noAvailableFirmware("No valid firmware releases found.") }
                return latest
            }
            .eraseToAnyPublisher()
    }

    /// Find all compatible bootloaders for the given device type
    ///
    static func _getAllBootloaderAsync(hardwareRev: String,
                                       modelNumber: String
    ) -> AnyPublisher<[MWFirmwareServer.Build], Swift.Error> {

        MWFirmwareServer
            .getAllFirmwareAsync(hardwareRev: hardwareRev, modelNumber: modelNumber, buildFlavor: "bootloader")
    }

    /// Get only the most recent firmware (custom build flavor)
    ///
    static func _getLatestFirmwareAsync(hardwareRev: String,
                                        modelNumber: String,
                                        buildFlavor: String)
    -> AnyPublisher<MWFirmwareServer.Build,Swift.Error> {

        MWFirmwareServer
            .getAllFirmwareAsync(hardwareRev: hardwareRev, modelNumber: modelNumber, buildFlavor: buildFlavor)
            .tryMap { builds in
                guard let latest = builds.last
                else { throw MWFirmwareServer.Error.noAvailableFirmware("No valid firmware releases found.") }
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
    ) -> AnyPublisher<MWFirmwareServer.Build,Swift.Error> {

        var build = MWFirmwareServer.Build(
            hardwareRev: hardwareRev,
            modelNumber: modelNumber,
            buildFlavor: buildFlavor,
            firmwareRev: firmwareRev,
            filename: "firmware.zip",
            requiredBootloader: requiredBootloader
        )

        return downloadAsync(url: build.firmwareURL)
            .catch { error -> AnyPublisher<URL,Swift.Error> in
                build = MWFirmwareServer.Build(
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
    static func downloadAsync(url: URL) -> AnyPublisher<URL,Swift.Error> {

        return MWFirmwareServer.session
            .dataTaskPublisher(for: url)
#if DEBUG
            .print("MetaWear Downloading... \(url)")
#endif
            .retry(3)
            .tryMap(MWFirmwareServer.validateResponse)
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
                    throw MWFirmwareServer.Error.cannotSaveFile("Couldn't find temp directory to store firmware file.  Please report issue to developers@mbientlab.com")
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Internal - JSON/URLRequest Helpers

extension MWFirmwareServer {

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
        else { throw MWFirmwareServer.Error.badServerResponse }

        guard httpResponse.statusCode == 200
        else { throw MWFirmwareServer.Error.noAvailableFirmware("\(Self.self) \(Self.request().url!) returned code \(httpResponse.statusCode)") }

        return data
    }

    fileprivate typealias JSON = [String: [String: [String: [String: [String: String]]]]]

    fileprivate static func validateJSON(data: Data, response: URLResponse) throws -> JSON {
        try validateResponse(data: data, response: response)

        guard let info = try? JSONSerialization.jsonObject(with: data) as? JSON
        else { throw MWFirmwareServer.Error.badServerResponse }

        return info
    }

    fileprivate static func _parseFirmwaresFromValidJSON(
        _ info: MWFirmwareServer.JSON,
        _ device: (hardware: String, model: String, build: String)
    ) -> [MWFirmwareServer.Build] {

        guard let potentialVersions = info[device.hardware]?[device.model]?[device.build]
        else { return [] }

        let sdkVersion = Bundle(for: MetaWear.self).infoDictionary?["CFBundleShortVersionString"] as! String
        return potentialVersions
            .filter { sdkVersion.isMetaWearVersion(greaterThanOrEqualTo: $1["min-ios-version"]!) }
            .sorted { $0.key.isMetaWearVersion(lessThan: $1.key) }
            .map {
                MWFirmwareServer.Build(hardwareRev: device.hardware,
                              modelNumber: device.model,
                              buildFlavor: device.build,
                              firmwareRev: $0,
                              filename: $1["filename"]!,
                              requiredBootloader: $1["required-bootloader"]!)
            }

    }

}

// MARK: - Internal: Perform firmware update

/// Checks that the correct bootloader is installed before trying DFU.
///
/// Returns void + completion or failure when:
///  - DFUServiceDelegate calls the `dfuSourceCache` subject from `_runNordicInstall` (the terminal publisher)
///  - `_updateMetaBoot_` functions ensure bootloader version is appropriate before running Nordic. These may issue a failure if a bootloader is unavailable or if the device is disconnected.
///
func _updateMetaBoot(
    _ metaboot: MetaWear,
    _ build: MWFirmwareServer.Build,
    _ delegate: DFUProgressDelegate?
) -> AnyPublisher<Void,Error> {

    metaboot.connectPublisher()
        .eraseErrorType()
        .flatMap { _ in _updateMetaBoot_CheckBootLoaderVersion(metaboot, build, delegate) }
        .eraseToAnyPublisher()
}

func _updateMetaBoot_CheckBootLoaderVersion(
    _ metaboot: MetaWear,
    _ build: MWFirmwareServer.Build,
    _ delegate: DFUProgressDelegate?
) -> AnyPublisher<Void,Error> {

    // Does the device's firmware version meet the new firmware's required bootloader version (if specified)?
    let canPerformDfuUpdate = build.requiredBootloader == nil
    ? true
    : build.requiredBootloader == metaboot.info?.firmwareRevision

    return canPerformDfuUpdate
    ? build.getNordicFirmware()
        .flatMap { _runNordicInstall(metaboot: metaboot, firmware: $0, delegate: delegate) }
        .eraseToAnyPublisher()
    : _updateMetaBoot_UpgradeFirmwareToMeetBootloaderRequirement(build.requiredBootloader!, metaboot, build, delegate)
}

func _updateMetaBoot_UpgradeFirmwareToMeetBootloaderRequirement(
    _ requiredVersion: String,
    _ metaboot: MetaWear,
    _ build: MWFirmwareServer.Build,
    _ delegate: DFUProgressDelegate?
) -> AnyPublisher<Void,Error> {

    MWFirmwareServer
        ._getAllBootloaderAsync(hardwareRev: build.hardwareRev, modelNumber: build.modelNumber)
        .map { $0.first(where: { $0.firmwareRev == requiredVersion }) }

    /// If the server doesn't vend that version, throw an error.
    /// Otherwise, update the bootloader, then update the MetaWear firmware.
        .flatMap { bootloader -> AnyPublisher<Void, Error> in
            guard let bootloader = bootloader
            else { return _dfuFail(build, requiredVersion) }

            return _updateMetaBoot(metaboot, bootloader, delegate)
                .flatMap { _ in _updateMetaBoot(metaboot, build, delegate) }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
}

/// Call into the actual Nordic DFU library. Returns a reference to a callback cached in `dfuSourceCache`.
///
func _runNordicInstall(metaboot: MetaWear, firmware: DFUFirmware, delegate: DFUProgressDelegate?) -> PassthroughSubject<Void,Error> {
    let initiator = DFUServiceInitiator(queue: metaboot.apiAccessQueue).with(firmware: firmware)
    initiator.forceDfu = true // We also have the DIS which confuses the DFU library
    initiator.logger = metaboot
    initiator.delegate = metaboot
    initiator.progressDelegate = delegate

    initiatorCache[metaboot] = initiator

    let dfuSource = PassthroughSubject<Void,Error>()
    dfuSourceCache[metaboot] = dfuSource
    dfuControllerCache[metaboot] = initiator.start(target: metaboot.peripheral)
    return dfuSource
}

fileprivate func _dfuFail(_ build: MWFirmwareServer.Build, _ requiredLoaderVersion: String) -> AnyPublisher<Void,Error> {
    let message = "Could not perform DFU. Firmware \(build.firmwareRev) requires bootloader version '\(requiredLoaderVersion)' which does not exist."
    return Fail(outputType: Void.self, failure: MWError.operationFailed(message))
        .eraseToAnyPublisher()
}

// MARK: - DFU helpers

private var initiatorCache: [MetaWear: DFUServiceInitiator] = [:]
private var dfuSourceCache: [MetaWear: PassthroughSubject<Void,Error>] = [:]
private var dfuControllerCache: [MetaWear: DFUServiceController] = [:]

extension MetaWear: DFUServiceDelegate {

    public func dfuStateDidChange(to state: DFUState) {
        switch state {
        case .completed:
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                dfuSourceCache[self]?.send(completion: .finished)
            }
        default:
            break
        }
    }

    public func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        dfuSourceCache[self]?.send(completion: .failure(MWError.operationFailed(message)))
    }
}

extension MetaWear: LoggerDelegate {

    /// Converts log level for iOS DFU Library.
    ///
    public func logWith(_ level: iOSDFULibrary.LogLevel, message: String) {
        let newLevel: MWConsoleLogger.LogLevel = {
            switch level {
                case .debug:        return .debug
                case .verbose:      return .debug
                case .info:         return .info
                case .application:  return .info
                case .warning:      return .warning
                case .error:        return .error
            }
        }()

        logDelegate?.logWith(newLevel, message: message)
    }
}
