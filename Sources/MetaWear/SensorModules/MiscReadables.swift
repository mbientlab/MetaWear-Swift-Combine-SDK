// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import Combine

// MARK: - MAC Address

/// After connection or if remembered, a MetaWear's ``MetaWear/MetaWear/info`` property exposes the stable MAC address.
public struct MWMACAddress: MWDataConvertible, MWReadable {
    public typealias DataType = String
    public typealias RawDataType = String
    
    public let columnHeadings = ["Epoch", "MAC"]
    
    public func readableSignal(board: MWBoard) throws -> MWDataSignal? {
        //mbl_mw_settings_get_mac_data_signal(board)
        let macResponseHeader = ResponseHeader(moduleID: Module.settings.byte, registerID: READ_REGISTER(0x0B))
        let dataSignal = MWDataSignal(header: macResponseHeader, owner: board, interpreter: DataInterpreter.MAC_ADDRESS)
        return dataSignal
    }
}

extension MWReadable where Self == MWMACAddress {
    /// After connection or if remembered, a MetaWear's ``MetaWear/MetaWear/info`` property exposes the stable MAC address.
    public static var macAddress: Self { Self() }
}
