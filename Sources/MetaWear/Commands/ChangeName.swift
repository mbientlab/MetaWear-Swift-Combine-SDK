// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWearCpp

/// Changes only the device's Bluetooth advertising name (not any SDK metadata).
///
public struct MWChangeAdvertisingName: MWCommand {
    var newName: String

    public init(newName: String) throws {
        guard MetaWear.isNameValid(newName)
        else { throw MWError.operationFailed("Invalid name") }
        self.newName = newName
    }

    public func command(board: MWBoard) {
        var data = [UInt8](newName.utf8)
        mbl_mw_settings_set_device_name(board, &data, .init(data.endIndex))
    }
}


// MARK: - Public Presets

public extension MWCommand where Self == MWChangeAdvertisingName {
    static func rename(advertisingName: String) throws -> Self {
        try Self.init(newName: advertisingName)
    }
}
