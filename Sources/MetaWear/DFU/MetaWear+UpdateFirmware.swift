/**
 * MetaWear+Firmware.swift
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
import MetaWearCpp
import iOSDFULibrary
import Combine


// MARK: - Perform Firmware Update

public extension MetaWearFirmwareServer {

    /// Install the provided firmware (or latest if none provided)
    ///
    func updateFirmware(on device: MetaWear, delegate: DFUProgressDelegate? = nil, build: FirmwareBuild? = nil) -> AnyPublisher<Void,Error> {

        // Proceed with a connection
        device
            .connectPublisher()
            .eraseErrorType()

        // Use provided or default to latest firmware
            .flatMap { [weak self, weak device] _ -> AnyPublisher<FirmwareBuild, Error> in
                guard let self = self, let device = device
                else { return _Fail(.operationFailed("Self/device unavailable")) }

                if let build = build { return _Just(build) }
                else { return self.fetchLatestFirmware(for: device) }
            }

        // Ensure in MetaBoot mode
            .flatMap { [weak device, weak delegate] build -> AnyPublisher<Void,Error> in
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

// MARK: - Internal: Perform firmware update

/// Checks that the correct bootloader is installed before trying DFU.
///
/// Returns void + completion or failure when:
///  - DFUServiceDelegate calls the `dfuSourceCache` subject from `_runNordicInstall` (the terminal publisher)
///  - `_updateMetaBoot_` functions ensure bootloader version is appropriate before running Nordic. These may issue a failure if a bootloader is unavailable or if the device is disconnected.
///
func _updateMetaBoot(
    _ metaboot: MetaWear,
    _ build: FirmwareBuild,
    _ delegate: DFUProgressDelegate?
) -> AnyPublisher<Void,Error> {

    metaboot.connectPublisher()
        .eraseErrorType()
        .flatMap { _ in _updateMetaBoot_CheckBootLoaderVersion(metaboot, build, delegate) }
        .eraseToAnyPublisher()
}

func _updateMetaBoot_CheckBootLoaderVersion(
    _ metaboot: MetaWear,
    _ build: FirmwareBuild,
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
    _ build: FirmwareBuild,
    _ delegate: DFUProgressDelegate?
) -> AnyPublisher<Void,Error> {

    MetaWearFirmwareServer
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

fileprivate func _dfuFail(_ build: FirmwareBuild, _ requiredLoaderVersion: String) -> AnyPublisher<Void,Error> {
    let message = "Could not perform DFU. Firmware \(build.firmwareRev) requires bootloader version '\(requiredLoaderVersion)' which does not exist."
    return Fail(outputType: Void.self, failure: MetaWearError.operationFailed(message))
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
        dfuSourceCache[self]?.send(completion: .failure(MetaWearError.operationFailed(message)))
    }
}

extension MetaWear: LoggerDelegate {

    /// Converts log level for iOS DFU Library.
    ///
    public func logWith(_ level: iOSDFULibrary.LogLevel, message: String) {
        let newLevel: LogLevel = {
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
