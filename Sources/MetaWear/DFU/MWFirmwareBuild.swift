// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import CoreBluetooth
import iOSDFULibrary
import Combine

public extension MWFirmwareServer {
    /// Describes location of a firmware file
    ///
    struct Build {
        public let hardwareRev: String
        public let modelNumber: String
        public let buildFlavor: String
        public let firmwareRev: String
        public let filename: String
        public let requiredBootloader: String?

        public let firmwareURL: URL

        public init(hardwareRev: String,
                    modelNumber: String,
                    buildFlavor: String,
                    firmwareRev: String,
                    filename: String,
                    requiredBootloader: String?) {
            self.hardwareRev = hardwareRev
            self.modelNumber = modelNumber
            self.buildFlavor = buildFlavor
            self.firmwareRev = firmwareRev
            self.filename = filename
            self.requiredBootloader = requiredBootloader

            self.firmwareURL = URL(string: "https://mbientlab.com/releases/metawear/\(hardwareRev)/\(modelNumber)/\(buildFlavor)/\(firmwareRev)/\(filename)")!
        }

        public init(hardwareRev: String,
                    modelNumber: String,
                    firmwareRev: String,
                    customUrl: URL,
                    filename: String? = nil,
                    buildFlavor: String? = nil,
                    requiredBootloader: String? = nil) {
            self.hardwareRev = hardwareRev
            self.modelNumber = modelNumber
            self.buildFlavor = buildFlavor ?? "vanilla"
            self.firmwareRev = firmwareRev
            self.filename = filename ?? "firmware.bin"
            self.requiredBootloader = requiredBootloader

            self.firmwareURL = customUrl
        }
    }
}

internal extension MWFirmwareServer.Build {

    func getNordicFirmware() -> AnyPublisher<DFUFirmware,Error> {
        let task = firmwareURL.isFileURL
        ? Just(firmwareURL).setFailureType(to: Error.self).eraseToAnyPublisher()
        : MWFirmwareServer.downloadAsync(url: firmwareURL)

        return task
            .tryMap { fileUrl -> DFUFirmware in
                var selectedFirmware: DFUFirmware?

                if fileUrl.pathExtension.caseInsensitiveCompare("zip") == .orderedSame {
                    selectedFirmware = DFUFirmware(urlToZipFile: fileUrl)
                } else {
                    selectedFirmware = DFUFirmware(urlToBinOrHexFile: fileUrl, urlToDatFile: nil, type: .application)
                }

                guard let firmware = selectedFirmware else {
                    throw MWError.operationFailed("invalid dfu file chosen '\(fileUrl.lastPathComponent)'")
                }
                return firmware
            }
            .eraseToAnyPublisher()
    }
}
