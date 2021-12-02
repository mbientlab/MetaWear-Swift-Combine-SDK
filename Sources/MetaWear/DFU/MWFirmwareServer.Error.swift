// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

public extension MWFirmwareServer {
    /// Errors when retrieving firmwares from the MbientLab servers
    ///
    enum Error: Swift.Error {
        /// If server is down or not responding
        case badServerResponse
        /// Unable to find a compatible firmware
        case noAvailableFirmware(_ message: String)
        /// Likely to never occur, unless device runs out of space
        case cannotSaveFile(_ message: String)
    }

}
