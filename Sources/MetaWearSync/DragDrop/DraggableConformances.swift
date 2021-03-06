// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import MetaWear

// MARK: - Draggable Types

fileprivate let UTTypePlainText = "public.plain-text"

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

@available(iOS 14.0, macOS 11, *)
public extension UTType {
    static let draggableMetaWear = UTType(exportedAs: DraggableMetaWear.identifierString, conformingTo: .data)
}
#endif

public extension DraggableMetaWear {
    static let identifierString = "com.mbientlabs.metawear.item"
    static let writableTypeIdentifiersForItemProvider = [identifierString, UTTypePlainText]
    static let readableTypeIdentifiersForItemProvider = [identifierString, UTTypePlainText]
}

extension DraggableMetaWear: NSItemProviderWriting {

    @discardableResult public func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        switch typeIdentifier {
            case DraggableMetaWear.identifierString:
                do {
                    let item = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
                    completionHandler(item, nil)
                } catch {
                    nslog(error: error, from: Self.self)
                    completionHandler(nil, error)
                }

            case UTTypePlainText:
                completionHandler(plainText.data(using: .utf8), nil)
            default: completionHandler(nil, CocoaError(.coderInvalidValue))
        }
        return nil
    }
}

extension DraggableMetaWear: NSItemProviderReading {

    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> DraggableMetaWear {
        guard let item = try NSKeyedUnarchiver.unarchivedObject(ofClass: DraggableMetaWear.self, from: data)
        else { throw CocoaError(.coderInvalidValue) }
        return item
    }
}


// MARK: - Conformances: AppKit

#if os(macOS)
import AppKit
public extension DraggableMetaWear {
    static let pasteboardType = NSPasteboard.PasteboardType(rawValue: DraggableMetaWear.identifierString)
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] { [pasteboardType, .string] }
}

extension DraggableMetaWear: NSPasteboardWriting {
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
            case .string: return plainText.data(using: .utf8)
            default: return try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
        }
    }

    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [Self.pasteboardType, .string]
    }
}

extension DraggableMetaWear: NSPasteboardReading {
    public convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard type == Self.pasteboardType else { return nil }
        guard let data = propertyList as? Data else { return nil }
        do {
            if let item = try NSKeyedUnarchiver.unarchivedObject(ofClass: DraggableMetaWear.self, from: data) {
                self.init(decoded: item)
            }
        } catch { nslog(error: error, from: Self.self) }
        return nil
    }
}
#endif


// MARK: - Conformance: Secure Coding

extension DraggableMetaWear: NSSecureCoding {

    public static let supportsSecureCoding = true

    public convenience init?(coder: NSCoder) {
        guard let source = coder.decodeObject(of: [NSData.self], forKey: "com.mbientlabs.metawear") as? NSData else { return nil }
        do {
            let item = try JSONDecoder().decode(Self.self, from: Data(source))
            self.init(decoded: item)
        } catch { nslog(error: error, from: Self.self); return nil }
    }

    public func encode(with coder: NSCoder) {
        do {
            let encoded = try JSONEncoder().encode(self)
            coder.encode(encoded, forKey: "com.mbientlabs.metawear")
        } catch { nslog(error: error, from: Self.self) }
    }
}

internal func nslog<S>(error: Error, from: S.Type, line: UInt = #line) {
    NSLog("MetaWearSync Error: \(from.self) \(line) \(error.localizedDescription)")
}

public extension DraggableMetaWear {

    convenience init?(secureCoding: NSSecureCoding?) throws {
        try self.init(secureCodedData: secureCoding as? Data)
    }

    convenience init?(secureCodedData: Data?) throws {
        guard let item = try NSKeyedUnarchiver.unarchivedObject(ofClass: DraggableMetaWear.self, from: secureCodedData ?? Data()) else { return nil }
        self.init(decoded: item)
    }
}

