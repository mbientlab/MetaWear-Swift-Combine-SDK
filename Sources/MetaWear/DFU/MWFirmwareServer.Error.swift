// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation

public extension MWFirmwareServer {
    /// Errors when retrieving firmwares from the MbientLab servers
    ///
    enum Error: Swift.Error {
        /// If server is down or not responding
        case badServerResponse
        /// If JSON decoding fails
         case invalidServerResponse(message: String)
        /// Unable to find a compatible firmware
        case noAvailableFirmware(_ message: String)
        /// Likely to never occur, unless device runs out of space
        case cannotSaveFile(_ message: String)

        var localizedDescription: String {
             switch self {
                 case .badServerResponse: return "Bad server response"
                 case .invalidServerResponse(message: let message): return "Invalid Server Response: \(message)"
                 case .noAvailableFirmware(let message): return "No Firmware Available: \(message)"
                 case .cannotSaveFile(let message): return "Cannot Save File: \(message)"
             }
         }
    }
}
