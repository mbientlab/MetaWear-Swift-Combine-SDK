// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear


/// Utility for drag-and-drop support of a group or a
/// single MetaWear in a list for UIKit, AppKit, and SwiftUI.
///
/// Add the ``DraggableMetaWear/identifierString`` to the `Exported Type identifiers`
/// and `Imported Type Identifiers` sections of your target. This type conforms
/// to `public.data`. A description is helpful, but other fields needn't be implemented.
///
public final class DraggableMetaWear: NSObject, Codable {

    /// Metadata-based representation of a group or a single MetaWear
    ///
    public var item: Item

    /// String representation with name, MAC, local CBPeripheral identifier, and serial number.
    ///
    public var plainText: String

    /// Metadata-based representation of a group or a single MetaWear
    ///
    public enum Item: Codable {
        case group(MetaWear.Group)
        case remembered(meta: MetaWear.Metadata, localID: CBPeripheralIdentifier?)
        case unknown(CBPeripheralIdentifier)
    }

    /// Utility for drag-and-drop support of a group or a single MetaWear in a list for UIKit, AppKit, and SwiftUI
    ///
    public init(item: Item) {
        self.item = item
        self.plainText = Self.makePlainTextRepresentation(for: item)
    }

    /// Conformance utility
    public init(decoded: DraggableMetaWear) {
        self.item = decoded.item
        self.plainText = Self.makePlainTextRepresentation(for: decoded.item)
    }
}

// MARK: - Plain Text Rep

private extension DraggableMetaWear {

    static func makePlainTextRepresentation(for item: Item) -> String {
        switch item {
            case .group(let group): return represent(group)
            case .remembered(let metadata, let localID): return represent(metadata, localID)
            case .unknown(let id): return represent(unknown: id)
        }
    }

    static func represent(_ group: MetaWear.Group) -> String {
        """
    \(group.name)
    MACs: \(group.deviceMACs.sorted().joined(separator: ", "))
    """
    }

    static func represent(_ meta: MetaWear.Metadata, _ localID: CBPeripheralIdentifier?) -> String {
        """
    \(meta.name)
    MAC: \(meta.mac)
    Serial: \(meta.serial)
    Local ID: \(localID?.uuidString ?? "Not previously connected on this machine.")
    """
    }

    static func represent(unknown: CBPeripheralIdentifier) -> String {
        "Local ID: \(unknown.uuidString)"
    }
}

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

@available(iOS 13.4, macOS 11, *)
public extension UTType {
    static let draggableMetaWear = UTType(exportedAs: DraggableMetaWear.identifierString, conformingTo: .data)
}
#endif
