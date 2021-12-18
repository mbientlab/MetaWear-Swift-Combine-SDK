// Copyright 2021 MbientLab Inc. All rights reserved. See LICENSE.MD.

import Foundation
import UniformTypeIdentifiers
import SwiftUI


/// Convenience for SwiftUI drag and drop support for grouped lists of MetaWear devices
///
public protocol MetaWearDropTargetVM: AnyObject, DropDelegate {

    /// Outcome of the proposed drop to reflect in the UI
    ///
    var dropOutcome: DraggableMetaWear.DropOutcome { get }

    /// Called on the main queue after a drop exit (empty array) or
    /// concurrently with validation (populated array).
    ///
    func updateDropOutcome(for drop: [DraggableMetaWear.Item])

    /// Background queue used with a DispatchGroup during drop decoding
    ///
    var dropQueue: DispatchQueue { get }

}

public extension DraggableMetaWear {

    enum DropOutcome {
        case addToGroup
        case deleteFromGroup
        case newGroup
        case noDrop
    }

}

// MARK: - SwiftUI Drop Delegate Convenience Implementation

public extension MetaWearDropTargetVM {

    /// Create an `NSItemProvider` from the representation you provide (or an empty non-initiating container if you pass nil).
    ///
    func makeDraggableMetaWearProvider(_ item: DraggableMetaWear.Item?) -> NSItemProvider {
        guard let item = item else { return .init() }
        let draggable = DraggableMetaWear(item: item)
        let provider = NSItemProvider()
        provider.registerObject(draggable, visibility: .ownProcess)
        provider.registerObject(NSString(string: draggable.plainText), visibility: .all)
        provider.registerDataRepresentation(forTypeIdentifier: UTType.data.identifier, visibility: .all) { block in
            draggable.loadData(
                withTypeIdentifier: DraggableMetaWear.UTtype.identifier,
                forItemProviderCompletionHandler: block
            )
        }
        return provider
    }

    /// Asynchronously parse the drop and update the `dropOutcome` state
    ///
    func validateDrop(info: DropInfo) -> Bool {
        dropQueue.async { [weak self] in
            let draggables = info.loadMetaWears() ?? []
            DispatchQueue.main.async { [weak self] in
                self?.updateDropOutcome(for: draggables.map(\.item))
            }
        }
        return info.willLoadMetaWears()
    }

    /// Update the `dropOutcome` state
    ///
    func dropExited(info: DropInfo) {
        self.updateDropOutcome(for: [])
    }
}


// MARK: - SwiftUI Drop Delegate

public extension DropInfo {

    func willLoadMetaWears() -> Bool {
        hasItemsConforming(to: [DraggableMetaWear.pasteboardType.rawValue])
    }

    /// Call on a background queue!
    ///
    func loadMetaWears() -> [DraggableMetaWear]? {
        let type = DraggableMetaWear.pasteboardType.rawValue
        guard hasItemsConforming(to: [type]) else { return nil }
        let providers = itemProviders(for: [type])
        let group = DispatchGroup()
        var items: [DraggableMetaWear] = []
        providers.forEach {
            group.enter()
            $0.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                do {
                    guard let item = try NSKeyedUnarchiver.unarchivedObject(ofClass: DraggableMetaWear.self, from: data ?? Data())
                    else { group.leave(); return }
                    items.append(item)
                } catch { print(error: error) }
                group.leave()
            }
        }
        group.wait()
        return items
    }
}

// MARK: - SwiftUI Drop w/ Binding

extension Array where Element == NSItemProvider {

    /// Call on a background queue!
    ///
    public func loadMetaWears() -> [DraggableMetaWear]? {
        guard self.isEmpty == false else { return nil }

        let group = DispatchGroup()
        var draggables: [DraggableMetaWear] = []

        forEach {
            group.enter()
            $0.loadItem(forTypeIdentifier: UTType.draggableMetaWearItem.identifier, options: nil) { coding, error in
                do {
                    let data = coding as? Data ?? Data()
                    let item = try NSKeyedUnarchiver.unarchivedObject(ofClass: DraggableMetaWear.self, from: data)
                    if let item = item { draggables.append(item) }
                    group.leave()
                } catch { group.leave(); print(error: error) }
            }
        }
        group.wait()
        return draggables.isEmpty ? nil : draggables
    }
}

